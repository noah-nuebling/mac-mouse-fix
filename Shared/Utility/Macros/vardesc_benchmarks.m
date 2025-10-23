
/*

Benchmark results

    format-printing an int and a char * (26 * 100) times, using clock(), 2018 Mac Mini, [Oct 2025], results in ms, using clang flags `-g -O3`

    ./a.out 2>&1| rg "time with"
        
        time with NSLog (no vardesc):  24.042000
        time with NSLog:               36.282000
        time with oslog (no vardesc):  0.072000
        time with oslog:               0.073000
        time with printf (no vardesc): 0.529000


    ./a.out 2>&1| rg "time with"                (While streaming logs (`log stream --level debug --predicate 'sender == "a.out"'`))
        time with NSLog (no vardesc):  64.845000
        time with NSLog:               75.917000
        time with oslog (no vardesc):  27.831000
        time with oslog:               46.741000
        time with printf (no vardesc): 0.524000
 
    Analysis:

        Overhead added by vardesc:
            NSLog:  50%
            os_log: 0%

        Overhead added by vardesc: (while streaming logs)
            NSLog:  17%
            os_log: 68%

        Observations: 
            - os_log with vardesc is always faster than NSLog without vardesc
                -> So if we switch to `os_log and vardesc` from `NSLog without vardesc` performance shouldn't get worse
            - While not streaming logs, vardesc has no overhead with os_log
            - The overhead from NSLog / os_log is insane compared to fprintf: (120x baseline overhead on NSLog) (while streaming logs)
                - We could NSLog merely 641 times in one frame while streaming logs (if we did nothing else than log things) [(2600 / 64.845) * 16 = 641]
            - Is the minor convenience from vardesc worth it? Idk. vardesc is totally unnecessary anyways. I'm just doing this for fun. 


    Claude 4.5 said clock() might be wrong here. Measured again using CLOCK_MONOTONIC:

        ./a.out 2>&1| rg "time with"
            time with NSLog (no vardesc):   26.106000
            time with NSLog:                39.038000
            time with oslog (no vardesc):   0.073000
            time with oslog:                0.074000
            time with printf (no vardesc):  3.312000

        ./a.out 2>&1| rg "time with"                (While streaming logs (`log stream --level debug --predicate 'sender == "a.out"'`))
            time with NSLog (no vardesc):   70.544000
            time with NSLog:                79.433000
            time with oslog (no vardesc):   35.457000
            time with oslog:                55.761000
            time with printf (no vardesc):  3.469000


        Observations:
            - printf seems to be the most affected. 6x slower now. 
            - Other observations seem to hold true
*/

#import "Foundation/Foundation.h"
#import "SharedMacros.h"
#import "time.h"
#import <os/log.h>

#define loopc(i, count) for (int i = 0; i < (count); i++)
//#define nowtime() ((double)clock() / CLOCKS_PER_SEC * 1000.0) /* in ms */
#define nowtime() ({ struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); (ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0); })
#define oslog(fmt, args...) os_log_debug(OS_LOG_DEFAULT, fmt, ## args)

int main(void) {

    #define TEST_COUNT 100

    #define runtest(name, dolog)                        \
        {                                               \
            double ts_start = nowtime();                \
            loopc(t, TEST_COUNT) {                      \
                char letters[] = "a is the letter";     \
                loopc(i, ('z' - 'a' + 1)) {             \
                    dolog;                              \
                    letters[0] += 1;                    \
                }                                       \
            }                                           \
            double ts_end = nowtime();                  \
            NSLog(@"time with " name ": %f", ts_end-ts_start); \
        }
    
    runtest("NSLog (no vardesc)",   NSLog(@"NSLog (no vardesc): "               "{ i: %d | letters: %s }", i, letters))
    runtest("NSLog",                NSLog(@"NSLog: "                            "%@", vardesc(i, letters)))
    runtest("oslog (no vardesc)",   oslog("oslog (no vardesc): "                "{ i: %d | letters: %s }", i, letters))
    runtest("oslog",                oslog("oslog: "                             "%@", vardesc(i, letters)))
    runtest("printf (no vardesc)",  fprintf(stderr, "printf (no vardesc): "     "{ i: %d | letters: %s }\n", i, letters))

    return 0;
}
