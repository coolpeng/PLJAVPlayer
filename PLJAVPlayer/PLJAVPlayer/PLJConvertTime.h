//
//  PLJConvertTime.h
//  PLJAVPlayer
//
//  Created by Edward on 16/12/14.
//  Copyright © 2016年 coolpeng. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PLJConvertTime : NSObject

/**
 *  时间转换
 *
 *  @param seconds 总秒数
 *
 *  @return 时分秒 00:00:00
 */
+ (NSString *)timeFormatFromTotalSeconds:(NSInteger)seconds;


@end
