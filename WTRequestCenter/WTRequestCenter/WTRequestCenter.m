//
//  WTRequestCenter.m
//  TestCache
//
//  Created by song on 14-7-19.
//  Copyright (c) 2014年 song. All rights reserved.
//  

#import "WTRequestCenter.h"

@implementation WTRequestCenter

//设置失效日期
+(void)setExpireTimeInterval:(NSTimeInterval)expireTime
{
    [[NSUserDefaults standardUserDefaults] setFloat:expireTime forKey:@"WTRequestCenterExpireTime"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

//失效日期
+(NSTimeInterval)expireTimeInterval
{
    
    CGFloat time = [[NSUserDefaults standardUserDefaults] floatForKey:@"WTRequestCenterExpireTime"];
    if (time==0) {
//        默认时效日期
        time = 3600*24;
    }
    return time;
}

+(BOOL)checkRequestIsExpired:(NSHTTPURLResponse*)request
{
//    NSHTTPURLResponse *res = (NSHTTPURLResponse*)response.response;
    NSDictionary *allHeaderFields = request.allHeaderFields;
    
    NSString *dateString = [allHeaderFields valueForKey:@"Date"];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"eee, dd MMM yyyy HH:mm:ss VVVV"];
    NSDate *now = [NSDate date];
    //            NSString *string = [formatter stringFromDate:now];
    //            NSLog(@"%@",string);
    NSDate *date = [formatter dateFromString:dateString];
    //            NSLog(@"%@",date);
    
    NSTimeInterval delta = [now timeIntervalSince1970] - [date timeIntervalSince1970];
    NSTimeInterval expireTimeInterval = [WTRequestCenter expireTimeInterval];
    if (delta<expireTimeInterval) {
//        没有失效
        return NO;
    }else
    {
//        失效了
        return YES;
    }
    
}


//清除所有缓存
+(void)clearAllCache
{
    NSURLCache *cache = [WTRequestCenter sharedCache];
    [cache removeAllCachedResponses];

}

//当前缓存大小
+(NSUInteger)currentDiskUsage
{
    NSURLCache *cache = [WTRequestCenter sharedCache];
    return [cache currentDiskUsage];
}



static NSOperationQueue *shareQueue = nil;
+(NSOperationQueue*)shareQueue
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
//        if (!shareQueue) {
            shareQueue = [[NSOperationQueue alloc] init];
            [shareQueue setSuspended:NO];
            [shareQueue setMaxConcurrentOperationCount:10];
            shareQueue.name = @"WTRequestCentershareQueue";
            
//        }
    });
    return shareQueue;
}

+(void)stopAllRequest
{
    [[WTRequestCenter shareQueue] cancelAllOperations];
}

+(NSURLCache*)sharedCache
{
    NSURLCache *cache = [NSURLCache sharedURLCache];
//    最大内存空间
    [cache setMemoryCapacity:1024*1024*10];//10M
//    最大储存（硬盘）空间
    [cache setDiskCapacity:1024*1024*100];//100M
    return cache;
}

//清除请求的缓存
+(void)removeRequestCache:(NSURLRequest*)request
{
    NSURLCache *cache = [WTRequestCenter sharedCache];
    [cache removeCachedResponseForRequest:request];
}
#pragma mark - 辅助




#pragma mark - Get

//get请求
//Available in iOS 5.0 and later.
+(NSURLRequest*)getWithURL:(NSURL*)url parameters:(NSDictionary*)parameters completionHandler:(void (^)(NSURLResponse* response,NSData *data,NSError *error))handler
{
    NSURLCache *cache = [WTRequestCenter sharedCache];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:1.0];

    NSMutableString *paramString = [[NSMutableString alloc] init];
    for (NSString *key in [parameters allKeys]) {
        NSString *value = [parameters valueForKey:key];
        NSString *str = [NSString stringWithFormat:@"%@=%@",key,value];
        [paramString appendString:str];
        [paramString appendString:@"&"];
    }
    NSMutableString *urlString = [[NSMutableString alloc] initWithFormat:@"%@?%@",url,paramString];
    request.URL = [NSURL URLWithString:urlString];
    NSCachedURLResponse *response =[cache cachedResponseForRequest:request];
    
    if (!response) {
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[WTRequestCenter shareQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
         {
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (handler) {
                     handler(response,data,connectionError);
                 }
             });
         }];
    }else
    {
        //NSDateFormatter 在iOS7.0以后是线程安全的，为了保证5.0可用，在这里用主线程括起来
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([response.response isKindOfClass:[NSHTTPURLResponse class]]) {
                
                BOOL isExpired = [WTRequestCenter checkRequestIsExpired:(NSHTTPURLResponse*)response.response];
                if (isExpired) {
                    if (handler) {
                        handler(response.response,response.data,nil);
                    }
                    [WTRequestCenter removeRequestCache:request];
//                    [WTRequestCenter getWithURL:url completionHandler:handler];
                    [WTRequestCenter getWithURL:url parameters:parameters completionHandler:handler];
                }else
                {
                    if (handler) {
                        handler(response.response,response.data,nil);
                    }
                }
                
                
                
            }
            
            
        });
    }
    
    return request;
}

#pragma mark - POST
// post 请求
//Available in iOS 5.0 and later.
//parameters
+(NSURLRequest*)postWithURL:(NSURL*)url parameters:(NSDictionary*)parameters completionHandler:(void (^)(NSURLResponse* response,NSData *data,NSError *error))handler
{
    NSURLCache *cache = [WTRequestCenter sharedCache];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:1.0];
    [request setHTTPMethod:@"POST"];
    
    NSMutableString *paramString = [[NSMutableString alloc] init];
    for (NSString *key in [parameters allKeys]) {
        NSString *value = [parameters valueForKey:key];
        NSString *str = [NSString stringWithFormat:@"%@=%@",key,value];
        [paramString appendString:str];
        [paramString appendString:@"&"];
    }
    NSLog(@"\nurl:\n%@  \nparameters:\n%@",url,parameters);
    paramString = [[paramString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    
    NSData *postData = [paramString dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:postData];
    
    NSCachedURLResponse *response =[cache cachedResponseForRequest:request];

    //        如果不存在，重新请求
    if (!response) {

        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[WTRequestCenter shareQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                   
                   dispatch_async(dispatch_get_main_queue(), ^{
                       
                       if (handler) {
               handler(response,data,connectionError);
                       }

                       
                       
                   });//end main
 
        }];
    }else
    {
        //NSDateFormatter 在iOS7.0以后是线程安全的，为了保证5.0可用，在这里用主线程括起来
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([response.response isKindOfClass:[NSHTTPURLResponse class]]) {
                
                BOOL isExpired = [WTRequestCenter checkRequestIsExpired:(NSHTTPURLResponse*)response.response];
                if (isExpired) {
                    if (handler) {
                        handler(response.response,response.data,nil);
                    }
                    [WTRequestCenter removeRequestCache:request];
                    [WTRequestCenter postWithURL:url parameters:parameters completionHandler:handler];
                }else
                {
                    if (handler) {
                        handler(response.response,response.data,nil);
                    }
                }
                
                
                
            }
            
            
        });
    }

    return request;
}

+(NSURLRequest*)postWithoutCacheURL:(NSURL*)url parameters:(NSDictionary*)parameters completionHandler:(void (^)(NSURLResponse* response,NSData *data,NSError *error))handler
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:1.0];
    [request setHTTPMethod:@"POST"];
    
    NSMutableString *paramString = [[NSMutableString alloc] init];
    for (NSString *key in [parameters allKeys]) {
        NSString *value = [parameters valueForKey:key];
        NSString *str = [NSString stringWithFormat:@"%@=%@",key,value];
        [paramString appendString:str];
        [paramString appendString:@"&"];
    }
    
    paramString = [[paramString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    
    NSData *postData = [paramString dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:postData];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[WTRequestCenter shareQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler) {
        handler(response,data,connectionError);
            }
        });
        
    }];
                       
    return request;
}


#pragma mark - Image
+(NSURLRequest *)uploadRequestWithURL: (NSURL *)url

                               data: (NSData *)data
                           fileName: (NSString*)fileName
{
    
    // from http://www.cocoadev.com/index.pl?HTTPFileUpload
    
    //NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] init] ;
    urlRequest.URL = url;
    
    [urlRequest setHTTPMethod:@"POST"];
    
    NSString *myboundary = @"---------------------------14737809831466499882746641449";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",myboundary];
    [urlRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    
    //[urlRequest addValue: [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundry] forHTTPHeaderField:@"Content-Type"];
    
    NSMutableData *postData = [NSMutableData data]; //[NSMutableData dataWithCapacity:[data length] + 512];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", myboundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"userfile\"; filename=\"%@\"\r\n", fileName]dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[NSData dataWithData:data]];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", myboundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [urlRequest setHTTPBody:postData];
    return urlRequest;
}


//图片上传
+(void)upLoadImageWithURL:(NSURL*)url
                     data:(NSData *)data
                 fileName:(NSString*)fileName
completionHandler:(void (^)(NSURLResponse* response,NSData *data,NSError *error))handler
{
    NSURLRequest *request = [WTRequestCenter uploadRequestWithURL:url data:data fileName:fileName];
    [NSURLConnection sendAsynchronousRequest:request queue:[WTRequestCenter shareQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler) {
                handler(response,data,connectionError);
            }
        });
    }];
}



//多图片上传
+(void)upLoadImageWithURL:(NSURL*)url datas:(NSArray*)datas fileNames:(NSArray*)names
completionHandler:(void (^)(NSURLResponse* response,NSData *data,NSError *error))handler
{
    for (int i=0; i<[datas count]; i++) {
        NSData *data = datas[i];
        NSString *name = names[i];
        [WTRequestCenter upLoadImageWithURL:url data:data fileName:name completionHandler:handler];
    }
}
 


//下载图片  Download  (Cache)
+(void)getImageWithURL:(NSURL*)url imageComplectionHandler:(void(^) (UIImage* image))handler
{
    [WTRequestCenter getWithURL:url  parameters:nil  completionHandler:^(NSURLResponse *response, NSData *data,NSError *error) {
        UIImage *image = [UIImage imageWithData:data];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler) {
                handler(image);
            }
        });
    }];
}



#pragma mark - URL
+(NSString *)baseURL
{
    return @"http://mapi.v1baobao.com";
}
//实际应用示例
+(NSString*)urlWithIndex:(NSInteger)index
{
    NSMutableArray *urls = [[NSMutableArray alloc] init];
//    0-9
    [urls addObject:@"article/detail"];
    [urls addObject:@"interface1"];
    [urls addObject:@"interface2"];
    [urls addObject:@"interface3"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    
//  10-19
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    [urls addObject:@"interface0"];
    
    
    
    NSString *url = urls[index];
    NSString *urlString = [NSString stringWithFormat:@"%@/%@",[WTRequestCenter baseURL],url];
    return urlString;
}


@end