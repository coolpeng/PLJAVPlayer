//
//  PLJConvertTime.m
//  PLJAVPlayer
//
//  Created by Edward on 16/12/14.
//  Copyright © 2016年 coolpeng. All rights reserved.
//

#import "PLJConvertTime.h"

@implementation PLJConvertTime

+ (NSString *)timeFormatFromTotalSeconds:(NSInteger)seconds {
    
    NSString *hour = [NSString stringWithFormat:@"%02ld",seconds/3600];
    NSString *minute = [NSString stringWithFormat:@"%02ld",(seconds%3600)/60];
    NSString *second = [NSString stringWithFormat:@"%02ld",seconds%60];
    
    NSString *time;
    if (hour != nil) {
        time = [NSString stringWithFormat:@"%@:%@:%@",hour,minute,second];
    }
    
    time = [NSString stringWithFormat:@"%@:%@",minute,second];
    
    return time;
}

@end
