//
//  NSData+XZ.m
//  xz_test
//
//  Created by Robin on 8/1/16.
//  Copyright © 2016 Robin.Chao. All rights reserved.
//

#import "NSData+XZ.h"
#import "lzma.h"


@implementation NSData (XZ) 

+ (NSData *)dataByxzCompressing:(NSData *)aData {
    @try {
        if ([aData length] == 0) {
            return aData;
        }
        
        lzma_stream zStream = LZMA_STREAM_INIT;
        zStream.next_in = (uint8_t *)[aData bytes];
        zStream.avail_in = (size_t)[aData length];
         
         
        lzma_options_lzma opt_lzma2 = {
//            .dict_size = 1U << 16,
            .dict_size = LZMA_DICT_SIZE_MIN,
            .lc = LZMA_LCLP_MIN,
            .lp = LZMA_LCLP_MIN,
            .pb = LZMA_PB_MIN,
            .preset_dict = NULL,
            .preset_dict_size = 0,
            .mode = LZMA_MODE_NORMAL,
            .nice_len = 128,
            .mf = LZMA_MF_HC3,
            .depth = 0,
        }; 
        
        
        lzma_filter filters[] = {
            { .id = LZMA_FILTER_X86, .options = NULL },
            { .id = LZMA_FILTER_LZMA2, .options = &opt_lzma2 },
            { .id = LZMA_VLI_UNKNOWN, .options = NULL },
        };
        
        
        lzma_mt mt = {
            .flags = 0,
            .block_size = 0,
            .timeout = 0,
            .preset = LZMA_PRESET_DEFAULT,
            .filters = filters,
            .check = LZMA_CHECK_NONE,
        };
        
        mt.threads = lzma_cputhreads();
        
        if (mt.threads == 0)
            mt.threads = 1;
         
        const uint32_t threads_max = 4;
        if (mt.threads > threads_max)
            mt.threads = threads_max;
        
        // Initialize the threaded encoder.
        lzma_ret ret = lzma_stream_encoder_mt(&zStream, &mt);

        if (ret != LZMA_OK) {
            const char *msg;
            switch (ret) {
                case LZMA_MEM_ERROR:
                    msg = "Memory allocation failed";
                    break;
                case LZMA_OPTIONS_ERROR:
                    msg = "Specified filter chain is not supported";
                    break;
                case LZMA_UNSUPPORTED_CHECK:
                    msg = "Specified integrity check is not supported";
                    break;
                default:
                    msg = "Unknown error, possibly a bug";
                    break;
            }
            
            fprintf(stderr, "Error initializing the encoder: %s (error code %u)\n",
                    msg, ret);
            return nil;
        } 
        
        NSUInteger full_length = [aData length];
        NSUInteger half_length = full_length / 2;
        
        NSMutableData *buf = [NSMutableData dataWithLength:full_length + half_length];
        
        
        while (1) {
            zStream.next_out = [buf mutableBytes] + zStream.total_out;
            zStream.avail_out = (size_t)([buf length] - zStream.total_out);
            
            lzma_action action = zStream.avail_in ? LZMA_RUN : LZMA_FINISH; 
            
            lzma_ret ret = lzma_code(&zStream, action);
            
            if (ret == LZMA_STREAM_END) {
                break;
            } else if (ret != LZMA_OK) {
                const char *msg;
                switch (ret) {
                    case LZMA_MEM_ERROR:
                        msg = "Memory allocation failed";
                        break;
                    case LZMA_DATA_ERROR:
                        msg = "File size limits exceeded";
                        break;
                    default:
                        msg = "Unknown error, possibly a bug";
                        break;
                }
                
                fprintf(stderr, "Encoder error: %s (error code %u)\n",
                        msg, ret);
                
                lzma_end(&zStream);
                
                return nil;
            }
        }
        
        lzma_end(&zStream);
        [buf setLength:(unsigned long)zStream.total_out];
        
        return [NSData dataWithData: buf];
    }
    @catch (NSException *exception) {
    }
    
    return nil;
}

@end
