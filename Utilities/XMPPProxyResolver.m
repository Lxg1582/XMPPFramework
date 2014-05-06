#import "XMPPProxyResolver.h"

#import "XMPPDeviceProxySettings.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

NSString *const XMPPProxyResolverErrorDomain = @"XMPPProxyResolverErrorDomain";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPProxyResolver ()

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPProxyResolver

- (id)initWithdDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq resolverQueue:(dispatch_queue_t)rq
{
	NSParameterAssert(aDelegate != nil);
	NSParameterAssert(dq != NULL);
	
	if ((self = [super init]))
	{
		delegate = aDelegate;
		delegateQueue = dq;
		
#if !OS_OBJECT_USE_OBJC
		dispatch_retain(delegateQueue);
#endif
    
		if (rq)
		{
			resolverQueue = rq;
#if !OS_OBJECT_USE_OBJC
			dispatch_retain(resolverQueue);
#endif
		}
		else
		{
			resolverQueue = dispatch_queue_create("XMPPProxyResolver", NULL);
		}
		
		resolverQueueTag = &resolverQueueTag;
		dispatch_queue_set_specific(resolverQueue, resolverQueueTag, resolverQueueTag, NULL);
		
		results = [[NSMutableArray alloc] initWithCapacity:4];
	}
	return self;
}

- (void)retrieveHTTPProxyListFromDeviceSettingsForTargetHost:(NSString *)host
{  
  dispatch_block_t block = ^{ @autoreleasepool {
		
		if (resolveInProgress || !host || [host length] == 0)
		{
			return;
		}
  
    resolveInProgress = YES;
    NSURL *targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", host]];
    [XMPPDeviceProxySettings
     retrieveProxyListForTargetURL:targetURL
     andOnComplete:^(NSArray *proxyList, NSError *error) {
       resolveInProgress = NO;
       if (error) {
         id theDelegate = delegate;
         
         dispatch_async(delegateQueue, ^{ @autoreleasepool {
           
           SEL selector = @selector(xmppProxyResolver:didNotRetrieveDueToError:);
           
           if ([theDelegate respondsToSelector:selector])
           {
             [theDelegate xmppProxyResolver:self didNotRetrieveDueToError:error];
           }
         }});
         return;
       }
       
       id theDelegate = delegate;
       
       dispatch_async(delegateQueue, ^{ @autoreleasepool {
         
         SEL selector = @selector(xmppProxyResolver:didRetrieveHTTPProxyList:);
         
         if ([theDelegate respondsToSelector:selector])
         {
           NSArray *HTTPProxyList = proxyList ? proxyList : @[];
           [theDelegate xmppProxyResolver:self didRetrieveHTTPProxyList:HTTPProxyList];
         }
         
       }});
     }];
  }};
  
  if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_async(resolverQueue, block);
}

@end
