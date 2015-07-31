//
//  VOVCManager.m
//  joylife
//
//  Created by Valo on 15/4/25.
//  Copyright (c) 2015年 ValoLee. All rights reserved.
//

#import "VOVCManager.h"

NSString const *VOVCName = @"name";
NSString const *VOVCController = @"vc";
NSString const *VOVCStoryboard = @"sb";
NSString const *VOVCISPresent = @"present";

#pragma mark - VOVCManagerRegistration, 页面url注册
@interface VOVCManagerRegistration: NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *controller;
@property (nonatomic, copy) NSString *storyboard;
@property (nonatomic, assign) BOOL isPresent;

+ (instancetype)registrationFromDictionary:(NSDictionary *)dic;

@end

@implementation VOVCManagerRegistration

+ (instancetype)registrationFromDictionary:(NSDictionary *)dic{
    if (!dic) {
        return nil;
    }
    VOVCManagerRegistration *registration = [[VOVCManagerRegistration alloc] init];
    NSString *name = dic[VOVCName];
    NSString *viewController = dic[VOVCController];
    if((!viewController || viewController.length == 0) ||
       (!name || name.length == 0)){
        return nil;
    }
    registration.name = name;
    registration.controller = viewController;
    registration.storyboard = dic[VOVCStoryboard];
    registration.isPresent = [dic[VOVCISPresent] boolValue];
    return registration;
}
@end

#pragma mark - VOVCManager,页面管理器
static VOVCManager *_sharedManager;

@interface VOVCManager ()
/** 记录当前的页面层次 */
@property (nonatomic, strong) NSMutableArray *viewControllers;
/** 记录当前的页面层次 */
@property (nonatomic, strong) NSMutableArray *naviControllers;
/** 获取当前的UINavigationController */
@property (nonatomic, weak, readonly) UINavigationController *currentNaviController;
/** 页面url注册 */
@property (nonatomic, strong) NSMutableArray *registerList;

@end

@implementation VOVCManager

#pragma mark - 创建单例对象
+ (instancetype)sharedManager{
    @synchronized(self){
        if (!_sharedManager) {
            _sharedManager = [[VOVCManager alloc] init];
        }
    }
    return _sharedManager;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone{
    if (!_sharedManager) {
        _sharedManager = [super allocWithZone:zone];
        [_sharedManager commonInit];
    }
    return _sharedManager;
}

+ (id)copyWithZone:(struct _NSZone *)zone{
    return _sharedManager;
}

- (void)commonInit{
    self.viewControllers = [NSMutableArray array];
    self.naviControllers = [NSMutableArray array];
    self.registerList    = [NSMutableArray array];
    [UIViewController record];
}

#pragma mark - UIViewController+Record使用
- (void)addViewController:(UIViewController *)viewController{
    if ([viewController isKindOfClass:[UIViewController class]] && ![NSStringFromClass([viewController class]) isEqualToString:@"UIInputWindowController"]) {
        [self.viewControllers addObject:viewController];
        [self printPathWithTag:@"Appear   "];
    }
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        [self.naviControllers addObject:viewController];
    }
}

- (void)removeViewController:(UIViewController *)viewController{
    if ([viewController isKindOfClass:[UIViewController class]]) {
        [self.viewControllers removeObject:viewController];
        [self printPathWithTag:@"Disappear"];
    }
}

#pragma mark - 打印信息
- (void)printPathWithTag:(NSString *)tag
{
#if VO_DEBUG
    NSString *paddingItems = @"";
    for (NSUInteger i = 0; i <= self.viewControllers.count; i++)
    {
        paddingItems = [paddingItems stringByAppendingFormat:@"--"];
    }
    
    NSLog(@"%@:%@> %@", tag, paddingItems, [self.viewControllers.lastObject description]);
#endif
}

#pragma mark - 当前页面
- (UIViewController *)currentViewController{
    return self.viewControllers.lastObject;
}

- (UINavigationController *)currentNaviController{
    if (self.currentViewController.navigationController) {
        return self.currentViewController.navigationController;
    }
    else{
        return self.naviControllers.lastObject;
    }
}

- (void)setParams:(NSDictionary *)params forObject:(NSObject *)obj{
    if (!params || ![params isKindOfClass:[NSDictionary class]]) {
        return;
    }
    for (NSString *key in params.allKeys) {
        id value = params[key];
        if (value && ![value isKindOfClass:[NSNull class]]) {
            SEL sel = NSSelectorFromString([NSString stringWithFormat:@"set%@:",key.capitalizedString]);
            if ([obj respondsToSelector:sel]) {
                [obj setValue:value forKey:key];
            }
        }
    }
}


#pragma mark - 页面创建
#pragma mark 从Xib或者代码创建页面
- (UIViewController *)viewController:(NSString *)aController storyboard:(NSString *)aStoryboard{
    return [self viewController:aController storyboard:aStoryboard params:nil];
}

- (UIViewController *)viewController:(NSString *)aController storyboard:(NSString *)aStoryboard params:(NSDictionary *)aParams{
    // 1. 参数检查
    if(!aController || aController.length == 0){
        return nil;
    }
    
    Class clazz = NSClassFromString(aController);
    if(!clazz){
        return nil;
    }
    
    // 2. 创建VC
    UIViewController *viewController = nil;
    if(aStoryboard && aStoryboard.length > 0){
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:aStoryboard bundle:nil];
        if (storyboard) {
            viewController = [storyboard instantiateViewControllerWithIdentifier:aController];
        }
    }
    else{
        viewController = [[clazz alloc] initWithNibName:aController bundle:nil];
        if(!viewController){
            viewController = [[clazz alloc] init];
        }
    }
    
    // 3. 设置ViewController参数
    [self setParams:aParams forObject:viewController];
    
    return viewController;
}


#pragma mark - 页面跳转,Push
- (void)pushController:(NSString *)aController storyboard:(NSString *)aStoryboard{
    [self pushController:aController storyboard:aStoryboard params:nil];
}

- (void)pushController:(NSString *)aController storyboard:(NSString *)aStoryboard params:(NSDictionary *)aParams{
    [self pushController:aController storyboard:aStoryboard params:aParams animated:YES];
}

- (void)pushController:(NSString *)aController storyboard:(NSString *)aStoryboard animated:(BOOL)animated{
    [self pushController:aController storyboard:aStoryboard params:nil animated:animated];
}

- (void)pushController:(NSString *)aController storyboard:(NSString *)aStoryboard params:(NSDictionary *)aParams animated:(BOOL)animated{
    UIViewController *viewController = [self viewController:aController storyboard:aStoryboard params:aParams];
    if(!viewController){
        return;
    }
    
    [self.currentNaviController pushViewController:viewController animated:animated];
}

- (void)pushController:(NSString *)aController storyboard:(NSString *)aStoryboard params:(NSDictionary *)aParams animated:(BOOL)animated removeControllers:(NSArray *)removeControllers{
    [self pushController:aController storyboard:aStoryboard params:aParams animated:animated];
    if(removeControllers == nil || self.currentNaviController == nil){
        return;
    }
    NSMutableArray *willRemoveControllers = [NSMutableArray array];
    NSMutableArray *tmpArray = [self.currentNaviController.viewControllers mutableCopy];
    for (NSString *removeController in removeControllers) {
        if (![removeController isEqualToString:aController]) {
            for (UIViewController *viewController in tmpArray) {
                if ([NSStringFromClass([viewController class]) isEqualToString:removeController]) {
                    [willRemoveControllers addObject:viewController];
                }
            }
        }
    }
    [tmpArray removeObjectsInArray:willRemoveControllers];
    self.currentNaviController.viewControllers = tmpArray;
}



#pragma mark - 页面出栈
- (UIViewController *)popViewControllerAnimated:(BOOL)animated{
    if (self.currentNaviController) {
        return [self.currentNaviController popViewControllerAnimated:animated];
    }
    return nil;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated{
    if (self.currentNaviController) {
        return [self.currentNaviController popToRootViewControllerAnimated:animated];
    }
    return nil;
}

- (NSArray *)popToViewController:(NSString *)aController storyboard:(NSString *)aStoryboard{
    return [self popToViewController:aController storyboard:aStoryboard params:nil];
}

- (NSArray *)popToViewController:(NSString *)aController storyboard:(NSString *)aStoryboard params:(NSDictionary *)aParams{
    return [self popToViewController:aController storyboard:aStoryboard params:aParams animated:YES];
}

- (NSArray *)popToViewController:(NSString *)aController storyboard:(NSString *)aStoryboard params:(NSDictionary *)aParams animated:(BOOL)animated{
    if(!aController || aController.length == 0){
        return nil;
    }
    
    Class clazz = NSClassFromString(aController);
    
    if(!clazz){
        return nil;
    }
    
    NSArray *viewControllers = [self.currentViewController.navigationController viewControllers];
    __block UIViewController *targetVC = nil;
    [viewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop){
        if([obj isKindOfClass:clazz]){
            targetVC = obj;
            *stop = YES;
        }
    }];
    if (targetVC) {
        [self setParams:aParams forObject:targetVC];
        return [self.currentViewController.navigationController popToViewController:targetVC animated:animated];
    }
    else{
        targetVC = [self viewController:aController storyboard:aStoryboard];
        if (targetVC) {
            [self setParams:aParams forObject:targetVC];
            NSMutableArray *targetVCs = [viewControllers mutableCopy];
            if (targetVCs.count > 1) {
                [targetVCs replaceObjectAtIndex:1 withObject:targetVC];
                [targetVCs removeObjectsInRange:NSMakeRange(2, targetVCs.count - 2)];
            }
            else{
                [targetVCs addObject:targetVC];
            }
            [self.currentViewController.navigationController setViewControllers:targetVCs animated:animated];
            return targetVCs;
        }
        else{
            return nil;
        }
    }
}

#pragma mark - 页面显示,present
- (void)presentViewController:(NSString *)aController storyboard:(NSString *)aStoryboard{
    [self presentViewController:aController storyboard:aStoryboard params:nil];
}

- (void)presentViewController:(NSString *)aController storyboard:(NSString *)aStoryboard params:(NSDictionary *)aParams{
    [self presentViewController:aController storyboard:aStoryboard params:aParams isInNavi:YES];
}

- (void)presentViewController:(NSString *)aController storyboard:(NSString *)aStoryboard params:(NSDictionary *)aParams isInNavi:(BOOL)inNavi{
    [self presentViewController:aController storyboard:aStoryboard params:aParams isInNavi:YES completion:nil];
}

- (void)presentViewController:(NSString *)aController storyboard:(NSString *)aStoryboard params:(NSDictionary *)aParams isInNavi:(BOOL)inNavi completion:(void (^)(void))completion{
    UIViewController *viewController = [self viewController:aController storyboard:aStoryboard params:aParams];
    if(inNavi){
        if (self.currentNaviController) {
            [self.currentNaviController presentViewController:viewController animated:YES completion:completion];
        }
        else{
        UINavigationController *naviController = [[UINavigationController alloc] initWithRootViewController:viewController];
            [self.currentViewController presentViewController:naviController animated:YES completion:completion];
        }
    }
    else{
        [self.currentViewController presentViewController:viewController animated:YES completion:completion];
    }
}

- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion{
    [self.currentViewController dismissViewControllerAnimated:animated completion:completion];
}

#pragma mark - 页面URL管理

- (void)registerWithSpec:(NSDictionary *)spec{
    [self.registerList addObject:[VOVCManagerRegistration registrationFromDictionary:spec]];
}

- (void)registerName:(NSString *)name forViewController:(NSString *)aController inStoryboard:(NSString *)aStoryboard isPresent:(BOOL)isPresent{
    if (!name || name.length == 0 || !aController || aController.length == 0) {
        return;
    }
    VOVCManagerRegistration *registration = [[VOVCManagerRegistration alloc] init];
    registration.name = name;
    registration.controller = aController;
    registration.storyboard = aStoryboard;
    registration.isPresent = isPresent;
    [self.registerList addObject:registration];
}

- (void)cancelRegisterName:(NSString *)name{
    VOVCManagerRegistration *tempRegistration = nil;
    for (VOVCManagerRegistration *registration in self.registerList) {
        if ([name isEqualToString:registration.name]) {
            tempRegistration = registration;
            break;
        }
    }
    if (tempRegistration) {
        [self.registerList removeObject:tempRegistration];
    }
}

- (BOOL)handleOpenURL:(NSURL *)url{
    NSAssert(url, @"url is nil!");
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
    /** 1.检查scheme是否匹配 */
    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    NSMutableArray *schemes = [NSMutableArray array];
    for (NSDictionary *dic in urlTypes) {
        NSArray *tmpArray  = dic[@"CFBundleURLSchemes"];
        [schemes addObjectsFromArray:tmpArray];
    }
    BOOL match = NO;
    for (NSString *scheme in schemes) {
        if ([scheme isEqualToString:components.scheme]) {
            match = YES;
            break;
        }
    }
    
    if (!match) {
        return NO;
    }
    
    /** 2. 获取页面名 */
    NSString *name = (!components.path||components.path.length == 0)? components.host : components.path.lastPathComponent;
    /** 3. 获取页面参数 */
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    /** iOS8.0+
    for (NSURLQueryItem *item in components.queryItems) {
        [params addEntriesFromDictionary:@{item.name: item.value}];
    }
     */
    /** iOS7.0 */
    NSArray *itemStringArray = [components.query componentsSeparatedByString:@"&"];
    for (NSString *itemString in itemStringArray) {
        NSRange range = [itemString rangeOfString:@"="];
        if (range.location != NSNotFound) {
            NSString *key = [itemString substringToIndex:range.location];
            NSString *val = [itemString substringFromIndex:range.location + range.length];
            [params addEntriesFromDictionary:@{key:val}];
        }
    }
    if (params.count == 0) {
        params = nil;
    }
    /** 打开对应页面 */
    [self showViewControllerWithRegisterName:name andParams:params];
    
    return YES;
}

/**
 *  显示相应的页面
 *
 *  @param name   页面的注册名
 *  @param params 页面的urlParams属性的值.如果要传递参数,对应页面必须有NSDictionay类型的urlParams属性(通过Key-Value的方式设置它的值)
 */
- (void)showViewControllerWithRegisterName:(NSString *)name andParams:(NSDictionary *)params{
    /** 1.检查是否注册,若注册,则获取相应的参数 */
    VOVCManagerRegistration *registration = nil;
    for (VOVCManagerRegistration *tmpRegistration in self.registerList) {
        if ([tmpRegistration.name isEqualToString:name]) {
            registration = tmpRegistration;
            break;
        }
    }
    if (!registration) {
        return;
    }
    /** 2.打开对应页面 */
    if (registration.isPresent) {
        [self presentViewController:registration.controller storyboard:registration.storyboard params:params];
    }
    else{
        [self pushController:registration.controller storyboard:registration.storyboard params:params];
    }
}

@end
