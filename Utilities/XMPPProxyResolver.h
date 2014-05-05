#import <Foundation/Foundation.h>

extern NSString *const XMPPProxyResolverErrorDomain;

@interface XMPPProxyResolver : NSObject
{
  __unsafe_unretained id delegate;
	dispatch_queue_t delegateQueue;
	
	dispatch_queue_t resolverQueue;
	void *resolverQueueTag;
  
  BOOL resolveInProgress;
  NSMutableArray *results;
}

/**
 * The delegate & delegateQueue are mandatory.
 * The resolverQueue is optional. If NULL, it will automatically create it's own internal queue.
 **/
- (id)initWithdDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq resolverQueue:(dispatch_queue_t)rq;

- (void)retrieveHTTPProxyListFromDeviceSettingsForTargetHost:(NSString *)host;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPProxyResolverDelegate

- (void)xmppProxyResolver:(XMPPProxyResolver *)sender didRetrieveHTTPProxyList:(NSArray *)HTTPProxyList;
- (void)xmppProxyResolver:(XMPPProxyResolver *)sender didNotRetrieveDueToError:(NSError *)error;

@end
