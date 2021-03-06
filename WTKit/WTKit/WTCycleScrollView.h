//
//  CycleScrollView.h
//  QuantGroup
//
//  Created by SongWentong on 15/2/3.
//  Copyright (c) 2015年 Spritekit. All rights reserved.
//

@import UIKit;
@class WTCycleScrollView;
//数据源
@protocol WTCycleScrollViewDataSource <NSObject>

-(NSInteger)numberOfViewInCycleScrollView:(WTCycleScrollView*)view;
-(UIView*)cycleScrollView:(WTCycleScrollView*)view viewForIndex:(NSInteger)index;

@end

//点击事件
@protocol WTCycleScrollViewDelegate <NSObject>
@optional
-(void)wtCycleScrollView:(WTCycleScrollView*)view didPressWithIndex:(NSInteger)index;


@end

/*
可循环的视图
使用范围:轮播图
这个东西我只是写着玩的,实际应用中使用collectionview就可以了.
*/
@interface WTCycleScrollView : UIView
@property (weak, nonatomic) id <WTCycleScrollViewDataSource> dataSource;
@property (weak, nonatomic) id <WTCycleScrollViewDelegate> delegate;
-(void)reloadData;


@end
