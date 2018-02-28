//
//  MapCarAI.h
//  GoCGM_Passenger
//
//  Created by T T Marshel Daniel on 28/02/18.
//  Copyright © 2018 T T Marshel Daniel. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "CarMarker.h"

@interface MapCarAI : NSObject

@property (nonatomic, readonly) CarMarker *marker;

+(instancetype)AIWithMapView:(GMSMapView *)mapView;
 
-(void)moveTo:(CLLocationCoordinate2D)coordinate;

@end
