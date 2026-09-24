#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

// Four-state bit encoding: a=known-one bits, b=unknown bits (X/Z collapse to X
// for AND); known zero is ~a & ~b. One event is one 32-bit vector AND.
struct V { uint32_t a,b; };
static V land4(V x,V y) {
  uint32_t zero=(~x.a & ~x.b) | (~y.a & ~y.b);
  uint32_t one=x.a & ~x.b & y.a & ~y.b;
  return {one,~(zero|one)};
}
static double ms(std::chrono::steady_clock::time_point a) {
  return std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-a).count();
}
static id<MTLComputePipelineState> pipeline(id<MTLDevice> d,id<MTLLibrary> l,NSString* name) {
  NSError* err=nil;
  id<MTLComputePipelineState> p=[d newComputePipelineStateWithFunction:[l newFunctionWithName:name] error:&err];
  if (!p) { fprintf(stderr,"pipeline %s: %s\n",name.UTF8String,err.description.UTF8String); exit(2); }
  return p;
}
static void dispatch(id<MTLCommandBuffer> cb,id<MTLComputePipelineState> p,
                     id<MTLBuffer> s,id<MTLBuffer> m,uint32_t n,uint32_t threads) {
  id<MTLComputeCommandEncoder> e=[cb computeCommandEncoder];
  [e setComputePipelineState:p]; [e setBuffer:s offset:0 atIndex:0];
  [e setBuffer:m offset:0 atIndex:1]; [e setBytes:&n length:sizeof(n) atIndex:2];
  [e dispatchThreads:MTLSizeMake(threads,1,1) threadsPerThreadgroup:MTLSizeMake(std::min<uint32_t>(threads,256),1,1)];
  [e endEncoding];
}
static void run(id<MTLCommandQueue> q,id<MTLComputePipelineState> p,
                id<MTLBuffer> s,id<MTLBuffer> m,uint32_t n,uint32_t threads) {
  id<MTLCommandBuffer> cb=[q commandBuffer]; dispatch(cb,p,s,m,n,threads);
  [cb commit]; [cb waitUntilCompleted];
  if (cb.status != MTLCommandBufferStatusCompleted) { fprintf(stderr,"Metal command failed: %s\n",cb.error.description.UTF8String); exit(3); }
}
int main() { @autoreleasepool {
  id<MTLDevice> d=MTLCreateSystemDefaultDevice();
  if (!d) { fprintf(stderr,"No Metal GPU\n"); return 2; }
  NSString* src=@"#include <metal_stdlib>\nusing namespace metal;\n"
  "uint2 land4(uint2 x,uint2 y){uint z=(~x.x & ~x.y) | (~y.x & ~y.y);uint o=x.x & ~x.y & y.x & ~y.y;return uint2(o,~(z|o));}\n"
  "kernel void batch(device uint2* s [[buffer(0)]],constant uint2* m [[buffer(1)]],constant uint& n [[buffer(2)]],uint i [[thread_position_in_grid]]){if(i<n)s[i]=land4(s[i],m[i]);}\n"
  "kernel void chain(device uint2* s [[buffer(0)]],constant uint2* m [[buffer(1)]],constant uint& n [[buffer(2)]],uint i [[thread_position_in_grid]]){if(i==0){uint2 v=s[0];for(uint j=0;j<n;++j)v=land4(v,m[j]);s[0]=v;}}\n"
  "kernel void step(device uint2* s [[buffer(0)]],constant uint2* m [[buffer(1)]],constant uint& n [[buffer(2)]],uint i [[thread_position_in_grid]]){if(i==0)s[0]=land4(s[0],m[n-1]);}\n";
  NSError* err=nil; id<MTLLibrary> l=[d newLibraryWithSource:src options:nil error:&err];
  if (!l) { fprintf(stderr,"Metal compile: %s\n",err.description.UTF8String); return 2; }
  id<MTLCommandQueue> q=[d newCommandQueue];
  auto batch=pipeline(d,l,@"batch"), chain=pipeline(d,l,@"chain"), step=pipeline(d,l,@"step");
  printf("GPU=%s\n",d.name.UTF8String);
  V warm{0xffffffffu,0};
  id<MTLBuffer> ws=[d newBufferWithBytes:&warm length:sizeof(V) options:MTLResourceStorageModeShared];
  id<MTLBuffer> wm=[d newBufferWithBytes:&warm length:sizeof(V) options:MTLResourceStorageModeShared];
  run(q,batch,ws,wm,1,1); run(q,chain,ws,wm,1,1); run(q,step,ws,wm,1,1);
  // Distinct state slots make event order unobservable within one region.
  for (uint32_t n: {4096u,65536u,1048576u}) {
    std::vector<V> init(n), mask(n), ref(n);
    for(uint32_t i=0;i<n;i++) {
      init[i]={i*2654435761u, i%7==0 ? 0x04000400u:0u};
      mask[i]={~(i*2246822519u), i%11==0 ? 0x10000010u:0u};
    }
    id<MTLBuffer> s=[d newBufferWithLength:n*sizeof(V) options:MTLResourceStorageModeShared];
    id<MTLBuffer> m=[d newBufferWithBytes:mask.data() length:n*sizeof(V) options:MTLResourceStorageModeShared];
    memcpy(s.contents,init.data(),n*sizeof(V)); ref=init;
    auto t=std::chrono::steady_clock::now();
    for(uint32_t i=0;i<n;i++) ref[i]=land4(ref[i],mask[i]);
    double cpu=ms(t); t=std::chrono::steady_clock::now();
    run(q,batch,s,m,n,n); double gpu=ms(t);
    bool ok=memcmp(s.contents,ref.data(),n*sizeof(V))==0;
    printf("batch n=%u cpu_ms=%.4f metal_submit_sync_ms=%.4f match=%d\n",n,cpu,gpu,ok);
    if(!ok)return 4;
  }
  // Each event consumes the prior event's state. One GPU thread can execute
  // the ordered chain, but provides no kernel parallelism.
  for(uint32_t n: {1024u,65536u}) {
    std::vector<V> mask(n); for(uint32_t i=0;i<n;i++) mask[i]={i*2654435761u, i%17==0?0x01000100u:0u};
    V init{0xffffffffu,0}; V ref=init;
    id<MTLBuffer> s=[d newBufferWithBytes:&init length:sizeof(V) options:MTLResourceStorageModeShared];
    id<MTLBuffer> m=[d newBufferWithBytes:mask.data() length:n*sizeof(V) options:MTLResourceStorageModeShared];
    auto t=std::chrono::steady_clock::now();
    for(uint32_t i=0;i<n;i++) ref=land4(ref,mask[i]); double cpu=ms(t);
    t=std::chrono::steady_clock::now(); run(q,chain,s,m,n,1); double gpu=ms(t);
    bool ok=memcmp(s.contents,&ref,sizeof(V))==0;
    printf("chain n=%u cpu_ms=%.4f metal_single_thread_ms=%.4f match=%d\n",n,cpu,gpu,ok);
    if(!ok)return 4;
  }
  // Scheduler-visible event feedback needs a synchronization after every
  // update; measure the fixed host/GPU crossing for 256 events.
  V init{0xffffffffu,0}; std::vector<V> mask(256,{0xffffffffu,0});
  id<MTLBuffer> s=[d newBufferWithBytes:&init length:sizeof(V) options:MTLResourceStorageModeShared];
  id<MTLBuffer> m=[d newBufferWithBytes:mask.data() length:mask.size()*sizeof(V) options:MTLResourceStorageModeShared];
  auto t=std::chrono::steady_clock::now();
  for(uint32_t i=1;i<=256;i++) run(q,step,s,m,i,1);
  printf("feedback n=256 metal_submit_sync_each_ms=%.4f match=%d\n",ms(t),memcmp(s.contents,&init,sizeof(V))==0);
  return 0;
} }
