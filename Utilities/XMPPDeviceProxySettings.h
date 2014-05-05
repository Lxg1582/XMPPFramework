#import <Foundation/Foundation.h>

typedef void (^ProxyListRetrievalCompletion)(NSArray *proxyList, NSError *error);

@interface XMPPDeviceProxySettings : NSObject

+ (void)retrieveProxyListForTargetURL:(NSURL *)targetURL
                        andOnComplete:(void (^)(NSArray *proxyList,
                                                NSError *error))onCompletion;

@end
