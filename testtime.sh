#!/usr/bin/env bash
# Replace !/bin/bash, because Mac `brew install bash`, the bash is /usr/local/bin/bash, not /bin/bash

source ./searchlogs.sh --export --start-datetime "2023-04-01 08:00:00"

# function parseFileTimeOpt() {
#     local optArray=()

#     if [[ -z "$1" ]]; then
#         fileDatetimeReg=""
#         fileDatetimeFormat=""
#         return 0
#     fi

#     IFS=',' read -ra optArray <<<"$1"

#     if [ ${optArray[0]+isset} ]; then
#         fileDatetimeReg="${optArray[0]}"
#     fi
#     if [ ${optArray[1]+isset} ]; then
#         fileDatetimeFormat="${optArray[1]}"
#     fi
# }

# function parseLineTimeOpt() {
#     local optArray=()

#     if [[ -z "$1" ]]; then
#         lineDatetimeReg=""
#         lineDatetimeFormat=""
#         return 0
#     fi

#     IFS=',' read -ra optArray <<<"$1"

#     if [ ${optArray[0]+isset} ]; then
#         lineDatetimeReg="${optArray[0]}"
#     fi
#     if [ ${optArray[1]+isset} ]; then
#         lineDatetimeFormat="${optArray[1]}"
#     fi
# }

function testFileTime() {
    local fileName="$1"
    isAllowedFileCheckers "$fileName"
    isAllowedFileFlag=$(echo $?)
    if [ ! $isAllowedFileFlag -eq 0 ]; then
        echo -e "\033[31m#$fileOptCount,$fileNameCount Error: Not Accepted file - \033[1;4m$fileName\033[0m"
    else
        echo -e "\033[32m#$fileOptCount,$fileNameCount Accepted file - \033[1;4m$fileName\033[0m"
    fi
}

function testLineTime() {
    local line="$1"
    isAllowedLineCheckers "$line"
    isAllowedLineFlag=$(echo $?)
    if [ ! $isAllowedLineFlag -eq 0 ]; then
        echo -e "\033[31m*$lineOptCount,$lineNameCount Error: Not Accepted Line - \033[1;4m$line\033[0m"
    else
        echo -e "\033[32m*$lineOptCount,$lineNameCount Accepted line - \033[1;4m$line\033[0m"
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
)

logFiles=(
    "/path/test_2023-03-31.log"
    "/path/test_2023-04-01.log"
    "/path/test_2023_04_01.log"
    "/path/test_20230402.log"
)

fileOptCount=1
fileNameCount=1
for fileDatetimeOpt in "${fileDatetimeOpts[@]}"; do
    fileNameCount=1

    # parseFileTimeOpt "$fileDatetimeOpt"
    IFS=',' read -ra fileDatetimeRegs <<< "$fileDatetimeOpt"
    fileDatetimeRegsLength=${#fileDatetimeRegs[@]}

    echo -e "\033[1;36m#$fileOptCount fileDatetimeOpt: \033[0m$fileDatetimeOpt\033[0m"
    echo -e "\033[1;36m#$fileOptCount fileDatetimeRegs: \033[0m(Length:${#fileDatetimeRegs[@]}) - ${fileDatetimeRegs[@]}\033[0m"

    for logFile in "${logFiles[@]}"; do
        testFileTime "$logFile"
        ((fileNameCount++))
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
lineNameCount=1
for lineDatetimeOpt in "${lineDatetimeOpts[@]}"; do
    lineNameCount=1

    # parseLinesTimeOpt "$lineDatetimeOpt"
    IFS=',' read -ra lineDatetimeRegs <<< "$lineDatetimeOpt"
    lineDatetimeRegsLength=${#lineDatetimeRegs[@]}

    echo -e "\033[1;36m*$lineOptCount lineDatetimeOpt: \033[0m$lineDatetimeOpt\033[0m"
    echo -e "\033[1;36m*$lineOptCount lineDatetimeRegs: \033[0m(Length:${#lineDatetimeRegs[@]}) - ${lineDatetimeRegs[@]}\033[0m"

    for logLine in "${logLines[@]}"; do
        testLineTime "$logLine"
        ((lineNameCount++))
    done

    ((lineOptCount++))
    echo ""
done

######## Test Line #########
