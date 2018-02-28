//
//  MapCarAI.m
//  GoCGM_Passenger
//
//  Created by palnar on 28/02/18.
//  Copyright © 2018 palnar. All rights reserved.
//

#import "MapCarAI.h"
#import <QuartzCore/QuartzCore.h>

#define degreesToRadians(x) (M_PI * x / 180.0)
#define radiansToDegrees(x) (x * 180.0 / M_PI)

typedef enum : NSUInteger {
    
    VehicleMovementAnimationWaiting,
    VehicleMovementAnimationAnimating,
    VehicleMovementAnimationCompleted,
    
} VehicleMovementAnimationStatus;


@class VehicleMovementAnimatonQueue;

@interface VehicleMovementAnimation : NSObject

@property (nonatomic, assign) BOOL isReSheduled;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) VehicleMovementAnimationStatus status;

@property (nonatomic, weak) VehicleMovementAnimatonQueue *Queue;

@property (nonatomic, copy) void (^rotation)(void);
@property (nonatomic, copy) void (^movement)(void);

+(instancetype)animateWithDuration:(NSTimeInterval)duration rotation:(void (^)(void))rotation movement:(void (^)(void))movement;
-(void)animate;

@end

@interface VehicleMovementAnimatonQueue : NSObject

@property (nonatomic, strong) NSMutableArray<VehicleMovementAnimation *> *animations;

+(instancetype)queue;
-(void)addAnimation:(VehicleMovementAnimation *)animation;

@end

@interface MapCarAI ()

@property (nonatomic, weak) GMSMapView *mapView;
@property (nonatomic, strong, readwrite) CarMarker *marker;

@property (nonatomic, strong) VehicleMovementAnimatonQueue *animatonQueue;

@property (nonatomic, strong) NSDate *lastUpdateTime;

@property (nonatomic, assign) CLLocationCoordinate2D previousPoint;

@end 

@implementation MapCarAI
 
+(instancetype)AIWithMapView:(GMSMapView *)mapView {
    
    MapCarAI *manager = [[self alloc] init];
    
    mapView.settings.rotateGestures = NO;
    [mapView setMinZoom:10.0 maxZoom:17.0];
    manager.mapView = mapView;
    
    return manager;
}

-(VehicleMovementAnimatonQueue *)animatonQueue {
    
    if (_animatonQueue) return _animatonQueue;
    
    self.animatonQueue = [VehicleMovementAnimatonQueue queue];
    
    return _animatonQueue;
}

-(CarMarker *)marker {
    
    if (_marker) { return _marker; }
    
    CarMarker *marker = [CarMarker markerWithCarType:@"sedan"];
    
    marker.map = self.mapView;
    self.marker = marker;
    return _marker;
}

-(void)moveTo:(CLLocationCoordinate2D)newCoodinate {
    
    if (CLLocationCoordinate2DIsValid(newCoodinate) == NO) return;
    
    if (_lastUpdateTime) {
        
        NSDate *newUpdateTime = [NSDate date];
        [self _moveTo:newCoodinate timeInterval:[self _timeIntervalBetween:_lastUpdateTime date2:newUpdateTime]];
        self.lastUpdateTime = newUpdateTime;
    } else {
        
        self.lastUpdateTime = [NSDate date];
        [self _moveTo:newCoodinate];
    }
}


-(NSTimeInterval)_timeIntervalBetween:(NSDate *)date1 date2:(NSDate *)date2 {
    
    return [date2 timeIntervalSinceDate:date1];
}

-(void)_moveTo:(CLLocationCoordinate2D)newCoodinate {
    
    [self _showPosition:newCoodinate];
}

-(void)_moveTo:(CLLocationCoordinate2D)newCoodinate timeInterval:(NSTimeInterval)timeInterval {
    
    CLLocationCoordinate2D oldCoodinate = self.previousPoint;
    
    if (CLLocationCoordinate2DIsValid(oldCoodinate) == NO) return;
    if (CLLocationCoordinate2DIsValid(newCoodinate) == NO) return;
    
    self.previousPoint = newCoodinate;
    
    NSTimeInterval movementSpeed = timeInterval;
    CLLocationDegrees rotation = [self _headingFromCoordinate:oldCoodinate toCoordinate:newCoodinate];
    
    __weak __typeof(self) __weakSelf = self;
    VehicleMovementAnimation *animation = [VehicleMovementAnimation animateWithDuration:movementSpeed rotation:^{
        
        __weakSelf.marker.rotation = rotation;
        
    } movement:^{
        
        __weakSelf.marker.position = newCoodinate;
        [__weakSelf _showPosition:newCoodinate];
    }];
    
    [self.animatonQueue addAnimation:animation];
}

-(void)_showPosition:(CLLocationCoordinate2D)position {
    
    GMSCameraUpdate *camera = [GMSCameraUpdate setTarget:position];
    [self.mapView animateWithCameraUpdate:camera];
    self.marker.position = position;
}

- (CLLocationDegrees)_headingFromCoordinate:(CLLocationCoordinate2D)fromLoc toCoordinate:(CLLocationCoordinate2D)toLoc
{
    float fLat = degreesToRadians(fromLoc.latitude);
    float fLng = degreesToRadians(fromLoc.longitude);
    float tLat = degreesToRadians(toLoc.latitude);
    float tLng = degreesToRadians(toLoc.longitude);
    
    float degree = radiansToDegrees(atan2(sin(tLng-fLng)*cos(tLat), cos(fLat)*sin(tLat)-sin(fLat)*cos(tLat)*cos(tLng-fLng)));
    
    if (degree >= 0) {
        return degree;
    } else {
        return 360+degree;
    }
}

@end

@implementation VehicleMovementAnimatonQueue

+(instancetype)queue {
    
    return [[self alloc] init];
}

-(void)addAnimation:(VehicleMovementAnimation *)animation {
    
    if (!animation) return;
    
    animation.Queue = self;
    
    if ([self _isAnyAnimationRunning] == NO) {
        
        if (animation.duration > 1.2) animation.duration = 1.2;
        
        [animation animate];
    }
    
    if ([self _needToIncreaseSpeedOfPendingAnimations] == YES) {
        
        [self _increaseTheSpeedOfPendingAnimations];
    }
    
    [self.animations addObject:animation];
}

-(NSMutableArray<VehicleMovementAnimation *> *)animations {
    
    if (_animations) return _animations;
    
    self.animations = [NSMutableArray array];
    return _animations;
}

-(BOOL)_isAnyAnimationRunning {
    
    for (VehicleMovementAnimation *temp in self.animations) {
        
        if (temp.status == VehicleMovementAnimationWaiting || temp.status == VehicleMovementAnimationAnimating) {
            return YES;
        }
    }
    return NO;
}

-(BOOL)_needToIncreaseSpeedOfPendingAnimations {
    
    if (self.animations.count > 2) return YES;
    return NO;
}

-(void)_increaseTheSpeedOfPendingAnimations {
    
    if (self.animations.count < 2) return ;
    
    for (NSInteger i = 1; i < self.animations.count; i++) {
        
        VehicleMovementAnimation *animation = self.animations[i];
        
        if (animation.status != VehicleMovementAnimationAnimating && !animation.isReSheduled) {
            
            animation.isReSheduled = YES;
            animation.duration = [self _reducedTimeOf:animation.duration];
        }
    }
}

-(NSTimeInterval)_reducedTimeOf:(NSTimeInterval)duration {
    
    if (duration > 20.0) return 2.6;
    if (duration > 10.0) return 2.4;
    if (duration > 6.0) return 1.8;
    if (duration > 4.0) return 1.5;
    if (duration > 3.0) return 1.4;
    if (duration > 2.0) return 1.2;
    
    if (duration < 0.4) return duration;
    
    return 0.8;
}

-(void)vehicleMovementAnimationDidCompleted:(VehicleMovementAnimation *)animation {
    
    NSUInteger index = [self.animations indexOfObject:animation];
    
    if (index == NSNotFound) return;
    
    if (self.animations.count > index+1) {
        
        [self.animations[index+1] animate];
    }
    
    [self _removeCompletedAnimations];
}

-(void)_removeCompletedAnimations {
    
    NSMutableArray<VehicleMovementAnimation *> *completedAnimations = [NSMutableArray array];
    for (VehicleMovementAnimation *temp in self.animations) {
        
        if (temp.status == VehicleMovementAnimationCompleted) {
            [completedAnimations addObject:temp];
        }
    }
    
    [self.animations removeObjectsInArray:completedAnimations];
}

@end


@implementation VehicleMovementAnimation

+(instancetype)animateWithDuration:(NSTimeInterval)duration rotation:(void (^)(void))rotation movement:(void (^)(void))movement {
    
    VehicleMovementAnimation *animation = [[[self class] alloc] init];
    
    animation.status = VehicleMovementAnimationWaiting;
    animation.duration = duration;
    animation.rotation = rotation;
    animation.movement = movement;
    
    return animation;
}

-(void)animate {
    
    self.status = VehicleMovementAnimationAnimating;
    __weak __typeof(self) __weakSelf = self;
    
    [CATransaction begin];
    [CATransaction setValue:[NSNumber numberWithFloat:0.3] forKey:kCATransactionAnimationDuration];
    if (self.rotation) _rotation();
    [CATransaction commit];
    
    [CATransaction begin];
    [CATransaction setValue:[NSNumber numberWithFloat:_duration] forKey:kCATransactionAnimationDuration];
    
    [CATransaction setCompletionBlock:^{
        
        __weakSelf.status = VehicleMovementAnimationCompleted;
        [__weakSelf.Queue vehicleMovementAnimationDidCompleted:self];
    }];
    
    if (self.movement) _movement();
    
    [CATransaction commit];
}

@end
