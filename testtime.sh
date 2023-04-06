#!/usr/bin/env bash
# Replace !/bin/bash, because Mac `brew install bash`, the bash is /usr/local/bin/bash, not /bin/bash

source ./searchlogs.sh --export --start-datetime "2023-04-01 08:00:00"

declare -A datetimeOptLength=(
    ["%Y"]=4
    ["%m"]=2
    ["%d"]=2
    ["%H"]=2
    ["%M"]=2
    ["%S"]=2
)
declare -A datetimeCompletion=(
    ["%Y"]="2023"
    ["%m"]="04"
    ["%d"]="01"
    ["%H"]="23"
    ["%M"]="59"
    ["%S"]="59"
)
function fileDateComplete()
{
    # Todo: Complete the datetime.
    # Here are the global variables you need
    # fileDatetime - The datetime matched by file datetime reg
    # fileDatetimeFormat - The current file datetime format when traversing ile-time-reg
    # fileDatetimeReg - The current file datetime reg when traversing ile-time-reg

    datetimeCompletion["%Y"]="2023"
    datetimeCompletion["%m"]="04"
    datetimeCompletion["%d"]="01"
    datetimeCompletion["%H"]="23"
    datetimeCompletion["%M"]="59"
    datetimeCompletion["%S"]="59"

    while IFS= read -r -d "" -n 1 c; do
        case $c in
            %)
                continue
                ;;
            Y|m|d|H|M|S)
                datetimeCompletion["%$c"]=${fileDatetime:0:${datetimeOptLength["%$c"]}}
                fileDatetime=${fileDatetime:${datetimeOptLength["%$c"]}}
                ;;
            *)
                fileDatetime=${fileDatetime:1}}
        esac
    done < <(printf '%s' "$fileDatetimeFormat")

    fileDatetimeFormat="%Y-%m-%d %H:%M:%S"
    fileDatetime="${datetimeCompletion[%Y]}-${datetimeCompletion[%m]}-${datetimeCompletion[%d]} ${datetimeCompletion[%H]}:${datetimeCompletion[%M]}:${datetimeCompletion[%S]}"

    echo "# Auto datetime complete: $fileDatetimeFormat - $fileDatetime"
}

function lineDateComplete()
{
    # Todo: Complete the datetime.
    # Here are the global variables you need
    # lineDatetime - The datetime matched by line datetime reg
    # lineDatetimeFormat - The current line datetime format when traversing ile-time-reg
    # lineDatetimeReg - The current line datetime reg when traversing ile-time-reg

    datetimeCompletion["%Y"]="2023"
    datetimeCompletion["%m"]="04"
    datetimeCompletion["%d"]="01"
    datetimeCompletion["%H"]="23"
    datetimeCompletion["%M"]="59"
    datetimeCompletion["%S"]="59"

    while IFS= read -r -d "" -n 1 c; do
        case $c in
            %)
                continue
                ;;
            Y|m|d|H|M|S)
                datetimeCompletion["%$c"]=${lineDatetime:0:${datetimeOptLength["%$c"]}}
                lineDatetime=${lineDatetime:${datetimeOptLength["%$c"]}}
                ;;
            *)
                lineDatetime=${lineDatetime:1}}
        esac
    done < <(printf '%s' "$lineDatetimeFormat")

    lineDatetimeFormat="%Y-%m-%d %H:%M:%S"
    lineDatetime="${datetimeCompletion[%Y]}-${datetimeCompletion[%m]}-${datetimeCompletion[%d]} ${datetimeCompletion[%H]}:${datetimeCompletion[%M]}:${datetimeCompletion[%S]}"

    echo "# Auto datetime complete: $lineDatetimeFormat - $lineDatetime"
}
# eval file"$(declare -f DateComplete)"
# eval line"$(declare -f DateComplete)"

function testFileTime() {
    file="$1"
    isAllowedFileCheckers
    isAllowedFileFlag=$(echo $?)
    if [ ! $isAllowedFileFlag -eq 0 ]; then
        echo -e "\033[31m#$fileOptCount,$fileCount Error: Not Accepted file - \033[1;4m$file\033[0m"
    else
        echo -e "\033[32m#$fileOptCount,$fileCount Accepted file - \033[1;4m$file\033[0m"
    fi
}

function testLineTime() {
    line="$1"
    isAllowedLineCheckers
    isAllowedLineFlag=$(echo $?)
    if [ ! $isAllowedLineFlag -eq 0 ]; then
        echo -e "\033[31m*$lineOptCount,$lineCount Error: Not Accepted Line - \033[1;4m$line\033[0m"
    else
        echo -e "\033[32m*$lineOptCount,$lineCount Accepted line - \033[1;4m$line\033[0m"
    fi
}

echo "=================================================================================================="
echo ""
######## Test File #########
fileDatetimeOpts=(
    ""
    "^.*/.*([0-9]{4}-[0-9]{2}-[0-9]{2}),%Y-%m-%d"
    "([0-9]{4}[0-9]{2}[0-9]{2}),%Y%m%d"
    "([0-9]{4}_[0-9]{2}_[0-9]{2}),%Y_%m_%d"
    "([0-9]{4}_[0-9]{2}_[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}),%Y_%m_%d %H:%M:%S"
)

logFiles=(
    "/path/test_2023-03-31.log"
    "/path/test_2023-04-01.log"
    "/path/test_2023_04_01.log"
    "/path/test_20230402.log"
    "/path/test_2023_04_01 10:00:01.log"
)

fileOptCount=1
fileCount=1
for fileDatetimeOpt in "${fileDatetimeOpts[@]}"; do
    fileCount=1

    # parseFileTimeOpt "$fileDatetimeOpt"
    IFS=',' read -ra fileDatetimeRegs <<< "$fileDatetimeOpt"
    fileDatetimeRegsLength=${#fileDatetimeRegs[@]}

    echo -e "\033[1;36m#$fileOptCount fileDatetimeOpt: \033[0m$fileDatetimeOpt\033[0m"
    echo -e "\033[1;36m#$fileOptCount fileDatetimeRegs: \033[0m(Length:${#fileDatetimeRegs[@]}) - ${fileDatetimeRegs[@]}\033[0m"

    for logFile in "${logFiles[@]}"; do
        testFileTime "$logFile"
        ((fileCount++))
    done

    ((fileOptCount++))
    echo ""
done
######## Test File #########
# exit
echo "=================================================================================================="
echo ""

######## Test Line #########
lineDatetimeOpts=(
    ""
    "([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}),%Y-%m-%d %H:%M:%S"
    "([0-9]{4}_[0-9]{2}_[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}),%Y_%m_%d %H:%M:%S"
    "([0-9]{4}[0-9]{2}[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}),%Y%m%d %H:%M:%S"
    "([0-9]{4}[0-9]{2}[0-9]{2}_[0-9]{2}:[0-9]{2}:[0-9]{2}),%Y%m%d_%H:%M:%S"
    "([0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}),%d-%m-%Y %H:%M:%S"
)

logLines=(
    "DEBUG  - 2023-04-01 10:00:01 --> Config Class Initialized"
    "DEBUG  - 2023_04_01 10:00:01 --> Config Class Initialized"
    "DEBUG  - 20230401 10:00:01 --> Config Class Initialized"
    "DEBUG  - 20230401_10:00:01 --> Config Class Initialized"
    "DEBUG  - 01-04-2023 10:00:01 --> Config Class Initialized"
)

lineOptCount=1
lineCount=1
for lineDatetimeOpt in "${lineDatetimeOpts[@]}"; do
    lineCount=1

    # parseLinesTimeOpt "$lineDatetimeOpt"
    IFS=',' read -ra lineDatetimeRegs <<< "$lineDatetimeOpt"
    lineDatetimeRegsLength=${#lineDatetimeRegs[@]}

    echo -e "\033[1;36m*$lineOptCount lineDatetimeOpt: \033[0m$lineDatetimeOpt\033[0m"
    echo -e "\033[1;36m*$lineOptCount lineDatetimeRegs: \033[0m(Length:${#lineDatetimeRegs[@]}) - ${lineDatetimeRegs[@]}\033[0m"

    for logLine in "${logLines[@]}"; do
        testLineTime "$logLine"
        ((lineCount++))
    done

    ((lineOptCount++))
    echo ""
done

######## Test Line #########
