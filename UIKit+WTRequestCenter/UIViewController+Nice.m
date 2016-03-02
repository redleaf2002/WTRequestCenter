//
//  UIViewController+Nice.m
//  WTRequestCenter
//
//  Created by SongWentong on 3/2/16.
//  Copyright © 2016 song. All rights reserved.
//

#import "UIViewController+Nice.h"
#import "WTNetWorkManager.h"
@implementation UIViewController (Nice)
-(void)showAlertWithMessage:(NSString*)message
{
    [self showAlertWithTitle:nil message:message duration:1.0 completion:nil];
}
-(void)showAlertWithTitle:(NSString*)title message:(NSString*)message duration:(NSTimeInterval)time completion: (void (^ __nullable)(void))completion
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [self presentViewController:alert animated:YES completion:^{
            
    }];
    [WTNetWorkManager performBlock:^{
        [alert dismissViewControllerAnimated:YES completion:completion];
    } afterDelay:time];
    
    
}
@end

@implementation UIViewController (IBHelper)

+(instancetype)instanceFromIB
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    NSString *name = NSStringFromClass(self);
    return [self instanceFromStoryBoard:sb name:name];
}

+(instancetype)instanceFromStoryBoardName:(NSString*)storyBoardName
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:storyBoardName bundle:nil];
    NSString *name = NSStringFromClass(self);
    return [self instanceFromStoryBoard:sb name:name];
}

+(instancetype)instanceFromStoryBoard:(UIStoryboard*)sb
{
    NSString *name = NSStringFromClass(self);
    return [self instanceFromStoryBoard:sb name:name];
}

+(instancetype)instanceFromStoryBoard:(UIStoryboard*)sb name:(NSString*)name
{
    return [sb instantiateViewControllerWithIdentifier:name];
}
@end