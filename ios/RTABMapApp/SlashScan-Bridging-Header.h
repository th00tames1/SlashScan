//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include "NativeWrapper.hpp"
#import <sqlite3.h>
#import "RTABMapAppObjC.h"

double calculateMeshVolumeNative(const void* object, int method);
void setVolumeMethodNative(const void* object, int method);
void setAutoGroundThresholdNative(const void* object, float threshold);
void setAutoGroundCutOffsetNative(const void* object, float offsetMeters);
void clearVolumePreviewNative(const void* object);
float estimateAutoGroundThresholdNative(const void* object);
void refreshAutoGroundPreviewNative(const void* object);
