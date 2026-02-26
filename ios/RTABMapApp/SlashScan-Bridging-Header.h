//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include "NativeWrapper.hpp"
#import <sqlite3.h>
#import "RTABMapAppObjC.h"

double calculateMeshVolumeNative(const void* object, int method);
void setVolumeMethodNative(const void* object, int method);
void setVolumeVisualizationModeNative(const void* object, int mode);
void setAutoGroundThresholdNative(const void* object, float threshold);
void clearVolumePreviewNative(const void* object);
