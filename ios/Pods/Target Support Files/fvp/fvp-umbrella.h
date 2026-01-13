#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "callbacks.h"
#import "dart_api_types.h"
#import "FvpPlugin.h"

FOUNDATION_EXPORT double fvpVersionNumber;
FOUNDATION_EXPORT const unsigned char fvpVersionString[];

