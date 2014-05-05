#import "XMPPDeviceProxySettings.h"

static dispatch_queue_t serialExecutionQueue;
static BOOL finishedExecutingProxyAutoConfigScript;
static NSArray *proxiesFromAutoConfigScript;

void proxyCallback(void *client,
                   CFArrayRef proxyList,
                   CFErrorRef error) {
  CFRetain(proxyList);
  proxiesFromAutoConfigScript = (NSArray *)CFBridgingRelease(proxyList);
  finishedExecutingProxyAutoConfigScript = YES;
}

@implementation XMPPDeviceProxySettings

+ (void)initialize {
  if (self == [XMPPDeviceProxySettings self]) {
    serialExecutionQueue = dispatch_queue_create("deviceProxySettingsRetrievalQueue",
                                                 DISPATCH_QUEUE_SERIAL);
  }
}

+ (void)retrieveProxyListForTargetURL:(NSURL *)targetURL
                        andOnComplete:(void (^)(NSArray *proxyList,
                                               NSError *error))onCompletion {
  // NOTE: Proxy list retrievals should always execute serially because they require
  //   a C callback and static variables.
  dispatch_async(serialExecutionQueue,
                 ^{ [self retrieveProxyListSynchronouslyForTargetURL:targetURL
                                                       andOnComplete:onCompletion]; });
}

+ (void)retrieveProxyListSynchronouslyForTargetURL:(NSURL *)targetURL
                                     andOnComplete:(ProxyListRetrievalCompletion)onCompletion {
  // Get proxy settings dictionary.
  NSDictionary *proxyDict = [self getProxyDictionaryFromSettings];
  if (!proxyDict) {
    [self callBackWithErrorUsingCompletionBlock:onCompletion];
    return;
  }
  if ([proxyDict count] == 0) {
    [self callbackSuccessWithProxyList:@[] usingCompletionBlock:onCompletion];
    return;
  }
  // Get proxy list.
  NSArray *proxyList = (NSArray *)CFBridgingRelease(CFNetworkCopyProxiesForURL((CFURLRef)CFBridgingRetain(targetURL),
                                                                               (CFDictionaryRef)CFBridgingRetain(proxyDict)));
  if (!proxyList) {
    [self callBackWithErrorUsingCompletionBlock:onCompletion];
    return;
  }
  if ([proxyList count] == 0) {
    [self callbackSuccessWithProxyList:proxyList usingCompletionBlock:onCompletion];
    return;
  }
  
  // Build HTTP Proxy List.
  NSMutableArray *HTTPProxyList = [NSMutableArray arrayWithCapacity:[proxyList count]];
  
  for (NSInteger index = 0; index < [proxyList count]; index++) {
    // Get Proxy Type.
    NSDictionary *proxy = proxyList[index];
    NSString *proxyType = proxy[(NSString *)kCFProxyTypeKey];
    
    if ([proxyType isEqualToString:(NSString *)kCFProxyTypeHTTP]) {
      [HTTPProxyList addObject:proxy];
      continue;
    }
    if ([proxyType isEqualToString:(NSString *)kCFProxyTypeAutoConfigurationURL]) {
      // Need to execute proxy auto configure URL.
      NSURL *proxyConfigURL = proxy[(NSString *)kCFProxyAutoConfigurationURLKey];
      NSArray *PACProxyList = [self executeAutoConfigurationScriptAtURL:proxyConfigURL targetURL:targetURL];
      if (proxyList) {
        
        for (NSDictionary *proxy in PACProxyList) {
          if ([proxyType isEqualToString:(NSString *)kCFProxyTypeHTTP]) {
            [HTTPProxyList addObject:proxy];
          }
        }
        
      }
      continue;
    }
    // Unsupported proxy type.
  }
  
  [self callbackSuccessWithProxyList:[HTTPProxyList copy] usingCompletionBlock:onCompletion];
}

+ (NSDictionary *)getProxyDictionaryFromSettings {
  return (NSDictionary *)CFBridgingRelease(CFNetworkCopySystemProxySettings());
}

+ (NSArray *)executeAutoConfigurationScriptAtURL:(NSURL *)proxyAutoConfigURL targetURL:(NSURL *)targetURL {
  finishedExecutingProxyAutoConfigScript = NO;
  proxiesFromAutoConfigScript = nil;
  
  CFStreamClientContext context = [self createEmptyStreamClientContext];
  CFRunLoopSourceRef loopSourceRef = CFNetworkExecuteProxyAutoConfigurationURL((__bridge CFURLRef)proxyAutoConfigURL,
                                                                               (__bridge CFURLRef)targetURL,
                                                                               proxyCallback,
                                                                               &context);
  CFRunLoopRef runLoop = CFRunLoopGetCurrent();
  CFRunLoopAddSource(runLoop, loopSourceRef, kCFRunLoopDefaultMode);
  
  while (!finishedExecutingProxyAutoConfigScript) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
  }
  CFRelease(loopSourceRef);
  
  return proxiesFromAutoConfigScript;
}

+ (CFStreamClientContext)createEmptyStreamClientContext {
  CFStreamClientContext context;
  context.version = 0;
  context.info = 0;
  context.retain = 0;
  context.release = 0;
  context.copyDescription = 0;
  return context;
}


#pragma mark - Callbacks

+ (void)callBackWithErrorUsingCompletionBlock:(ProxyListRetrievalCompletion)completionBlock {
  // TODO: Return a custom error code and domain.
  completionBlock ? completionBlock(@[], [NSError errorWithDomain:@"" code:-1 userInfo:nil]) : NULL;
}

+ (void)callbackSuccessWithProxyList:(NSArray *)proxyList
                usingCompletionBlock:(ProxyListRetrievalCompletion)completionBlock {
  completionBlock ? completionBlock(proxyList, nil) : NULL;
}

@end
