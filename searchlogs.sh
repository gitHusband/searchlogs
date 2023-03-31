#!/usr/bin/env bash
# Replace !/bin/bash, because Mac `brew install bash`, the bash is /usr/local/bin/bash, not /bin/bash

##############################################################################################
# Supports Platforms: Linux, Alpine, Mac

# 1. If run in Mac, must install gun-getopt by:
# % brew install gnu-getopt
# % echo 'export PATH="/usr/local/opt/gnu-getopt/bin:$PATH"' >> ~/.zshrc
# 2. If run in Mac, must install bash by:
# % brew install bash
##############################################################################################

function help()
{
    echo "
Search all log lines(Default to error lines) of all the log files in the path you set
Supports Platforms: Linux, Alpine, Mac
- If run in Mac, must install gun-getopt first
- If run in Alpine, make sure you have installed bash(apk add bash)

Usage:
  -p, --path                Find log files in here; Default to the path of script
  -n, --name                Regular expression of log file name; Default to *.log
  -s, --start-datetime      Search the logs write after this time; Default to yesterday
  -m, --match-reg           Search the lines of log files that match this regular expression
  --find-opts               Options of command find
  --save-log                Save logs that searched; Default to false
  --save-path               Save logs file path; Default to the path of script
  -c, --clean               Clean the save logs and exit
  --reset                   Clean the save logs and then search logs
  --line-offset-reg         It's allowed to display line without check if the line number is less than ((matchLineNumber+noCheckLineOffset))
                            - Set noCheckLineOffset if the line matches reg
                            - Format: reg1,noCheckLineOffset1,reg2,noCheckLineOffset2
  --file-time-reg           March datetime of the log files name
  --line-time-reg           March datetime of the a line of the log files
  -f, --follow              To not stop when end of log files is reached, but rather to wait for additional data to be appended to the log files
  -h, --help                Display this help and exit
 
  example1: $1 --path /data/vhosts
  example2: $1 --path "/data/vhosts" --name *.log --start-datetime \"2023-03-01 23:59:59\" --match-reg \"^ERROR\" --find-opts \"-o -name log*.php -mmin -3600\" --save-log
    "
}

# trim the start/end space of a string
function trim() {
    local str=""

    if [ $# -gt 0 ]; then
        str="$1"
    fi
    echo "$str" | sed -e 's/^[ \t\r\n]*//g' | sed -e 's/[ \t\r\n]*$//g'
}

# Get System Identifier：ubuntu、centos、alpine etc
function getOS() {
    local os=`uname`
    if [ "$os" == "Darwin" ]; then
        os="mac"
    else
        os=$(trim $(cat /etc/os-release 2>/dev/null | grep ^ID= | awk -F= '{print $2}'))

        if [ "$os" = "" ]; then
            os=$(trim $(lsb_release -i 2>/dev/null | awk -F: '{print $2}'))
        fi
        if [ ! "$os" = "" ]; then
            os=$(echo $os | tr '[A-Z]' '[a-z]')
        fi
    fi

    echo $os
}

# Default to yesterday
function getDefaultDatetime()
{
    if [ $os = "alpine" ]; then
        defaultDatetime=`date -d@"$((\`date +%s\`-86400))" +"%Y-%m-%d 00:00:00"` # Alpine
    elif [ $os = "mac" ]; then
        defaultDatetime=`date -v-1d +"%Y-%m-%d 00:00:00"` # Mac
    else
        defaultDatetime=`date -d last-day +"%Y-%m-%d 00:00:00"` # Linux
    fi

    echo $defaultDatetime
}

function strToTime()
{
    local dateTimeStr=$1
    local timestamp=0

    if [ $os = "mac" ]; then
        timestamp=`date -j -f "%Y-%m-%d %H:%M:%S" "$dateTimeStr" +%s` # Mac
    else
        timestamp=`date -d "$dateTimeStr" +%s` # Linux
    fi

    echo $timestamp
}

os=$(getOS)

# Find log files in here
path=`pwd`
# Regular expression of log file name
name='*.log'
# Search the logs write after this time
startDatetime=$(getDefaultDatetime)
# Search the lines of log files that match this regular expression
matchReg="^ERROR|WARNING|CRITICAL"
# Options of command find
findOpts=""
# Save logs that searched
isSaveLogs=0
# Save logs file path
savePath="`pwd`/searchlogs_result"
# Save file name suffix
saveNameSuffix='.search'
# Clean the save logs and exit
isClean=0
# Clean the save logs and then search logs
isReset=0
# It's allowed to display line without check if the line number is less than ((matchLineNumber+noCheckLineOffset))
# - Set noCheckLineOffset if the line matches reg
# - Format: reg1,noCheckLineOffset1,reg2,noCheckLineOffset2
lineOffsetReg=("^CRITICAL" 5 "Unexpected Exception" 6 "Debug backtrace" 6 "session data" 5)
# March datetime of the log files name
fileDatetimeReg="^.*/.*([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{8})"
# March datetime of the a line of the log files
lineDatetimeReg="([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})"
# If set to 1, means to not stop when end of log files is reached, but rather to wait for additional data to be appended to the log files
followFlag=0
# Follow interval, default to 3 seconds
followInterval=3

shortOpts="hp:n:s:m:fc"
longOpts="help,path:,name:,start-datetime:,match-reg:,find-opts:,save-log,save-path:,line-offset-reg:,file-time-reg:,line-time-reg:,follow,clean,reset"
getoptCmd=$(getopt -o $shortOpts -l "$longOpts" -n "$0" -- "$@")
[ $? -ne 0 ] && { echo "Try '$0 --help' for more information."; exit 1; }

eval set -- "$getoptCmd"
while true; do
    case "$1" in
        -h|--help) help $0;exit 0;;
        -p|--path) path=$2;shift;;
        -n|--name) name=$2;shift;;
        -s|--start-datetime) startDatetime=$2;shift;;
        -m|--match-reg) matchReg=$2;shift;;
        --find-opts) findOpts=$2;shift;;
        --save-log) isSaveLogs=1;;
        --save-path) savePath="$2/searchlogs_result";shift;;
        -c|--clean) isClean=1;;
        --reset) isReset=1;;
        --line-offset-reg) IFS=',' read -ra lineOffsetReg <<< "$2";shift;;
        --file-time-reg) fileDatetimeReg=$2;shift;;
        --line-time-reg) lineDatetimeReg=$2;shift;;
        -f|--follow) followFlag=1;;
        --) shift; break;;
        *) echo "$1 $2 is not supported";exit 1;;
    esac
    shift
done

# flag:
# - 0: Not follow flag
# - 1: Follow flag, to not stop when end of log files is reached, but rather to wait for additional data to be appended to the log files
FLAG_NOT_FOLLOW=0
FLAG_FOLLOW=1
function echoMsg()
{
    local msg=$1
    local flag=$2

    if [ $flag -eq $followFlag ]; then
        echo -e $msg
    fi
}

# Check if a file is allowed to dislpay
function isAllowedFileChecker()
{
    local file=$1
    
    if [[ $file =~ $fileDatetimeReg ]]; then
        fileDatetime=${BASH_REMATCH[1]}
        if [[ $fileDatetime =~ [0-9]{8} ]]; then
            day=${fileDatetime:$((${#fileDatetime} - 2))}
            month=${fileDatetime:$((${#fileDatetime} - 4)):2}
            year=${fileDatetime:0:$((${#fileDatetime} - 4))}
            fileDatetime="$year-$month-$day"
        fi
        fileDatetime="$fileDatetime 23:59:59"
        # echo $fileDatetime

        startTimeStamp=$(strToTime "$startDatetime")
        fileTimeStamp=$(strToTime "$fileDatetime")
        if [ $fileTimeStamp -ge $startTimeStamp ]; then
            # echo "fileDatetime($fileDatetime#$fileTimeStamp) >= startDatetime($startDatetime#$startTimeStamp)"

            # Will display this file
            return 1
        else
            # echo "fileDatetime($fileDatetime#$fileTimeStamp) < startDatetime($startDatetime#$startTimeStamp)"

            # Will not display this file
            return 0
        fi
    fi

    return 0
}

# Check if a line is allowed to dislpay
function isAllowedLineChecker()
{
    local line=$1

    if [[ $line =~ $lineDatetimeReg ]]; then
        lineDatetime=${BASH_REMATCH[1]}
        # echo $lineDatetime

        startTimeStamp=$(strToTime "$startDatetime")
        lineTimeStamp=$(strToTime "$lineDatetime")
        if [ $lineTimeStamp -ge $startTimeStamp ]; then
            # echo "lineDatetime($lineDatetime#$lineTimeStamp) >= startDatetime($startDatetime#$startTimeStamp)"

            # Will display this line
            return 1
        else
            # echo "lineDatetime($lineDatetime#$lineTimeStamp) < startDatetime($startDatetime#$startTimeStamp)"

            # Will not display this line
            return 0
        fi
    fi

    return 0
}

# It's allowed to display line without check if the line number is less than ((matchLineNumber+noCheckLineOffset))
function getLineOffset()
{
    local line=$1
    local lineOffset=0
    local lineOffsetRegIndex=0
    while ((lineOffsetRegIndex < ${#lineOffsetReg[@]}))
    do
        # echo "$lineOffsetRegIndex - ${lineOffsetReg[$lineOffsetRegIndex]}"
        if [[ $line =~ ${lineOffsetReg[$lineOffsetRegIndex]} ]]; then
            # echo -e "\033[33m  ${BASH_REMATCH[1]}\033[0m"
            ((lineOffsetRegIndex++))
            # echo "#$lineOffsetRegIndex ${lineOffsetReg[$lineOffsetRegIndex]}"
            lineOffset=${lineOffsetReg[$lineOffsetRegIndex]}
            break;
        else 
            ((lineOffsetRegIndex++))
        fi
        ((lineOffsetRegIndex++))
    done

    return $lineOffset
}

displayTotalLines=0
# Display a line
# If save log, then save the line into save file
# Return the line number offset that will display without check
function displayLine()
{
    local line=$1
    local lineNumber=$2
    local noCheckLineNumber=$3
    local saveFile=$4

    local noCheckLineOffset=0

    # Display line without check if the line number is less than noCheckLineNumber
    if [ $lineNumber -le $noCheckLineNumber ]; then
        ((displayTotalLines++))
        echo -e "\033[33m  $line\033[0m"
        if [[ -n "$saveFile" && -e $saveFile ]]; then echo "  $line" >> $saveFile; fi
        return $((noCheckLineNumber - lineNumber))
    fi

    if [[ $line =~ $matchReg ]]; then
        ((displayTotalLines++))
        echo -e "\033[32m$lineNumber:$line\033[0m"
        if [[ -n "$saveFile" && -e $saveFile ]]; then echo "$lineNumber:$line" >> $saveFile; fi
        # noCheckLineOffset=0
        getLineOffset "$line"
        noCheckLineOffset=`echo $?`
    fi

    return $noCheckLineOffset
}

# Create save file if need to save file
function createSaveFile()
{
    local logFile=$1
    local saveFile=${logFile/$pathWithoutEndSlash/$savePath}
    # saveFile=${saveFile/.log/.search.log}
    local saveFile=$saveFile$saveNameSuffix
    # echo "1. $logFile"
    # echo "2. $saveFile"

    # saveName=${saveFile##*/}
    local currentSavePath=${saveFile%/*}

    if [ ! -e $currentSavePath ]; then
        mkdir -p $currentSavePath
    fi

    if [ ! -e $saveFile ]; then
        touch $saveFile
    fi

    echo $saveFile;
}

# Display "last line number"/"total lines"/"datetime" of log file
# If save log, then save the "last line number"/"total lines"/"datetime" into save file
function displayDetails()
{
    local logFile=$1
    local lastLineNumber=$2
    local saveFile=$3
    local displayLines=$4

    datetime=`date +"%Y-%m-%d %H:%M:%S"`

    echoMsg "\033[4;36m# Last Line: $lastLineNumber - Display Total Lines: $displayLines - $datetime - $logFile\033[0m\n" $FLAG_NOT_FOLLOW

    if [ $followFlag = 1 ]; then
        # If follow new lines, display to terminal to know which file is the line belong to
        if [ -z "${followData["$logFile,displayLines"]}" ] || [[ -n "${followData["$logFile,displayLines"]}" && $displayLines -gt ${followData["$logFile,displayLines"]} ]]; then
            echo -e "\033[4;36m# Last Line: $lastLineNumber - Display Total Lines: $displayLines - $datetime - $logFile\033[0m\n"
        fi
    else
        persistDetailsToSaveFile $logFile "$saveFile" $lastLineNumber $displayLines "$datetime"
    fi

    setFollowData $logFile $lastLineNumber $displayLines "$datetime" "$saveFile"
}

# Persist details to the end of the save file
function persistDetailsToSaveFile()
{
    local logFile=$1
    local saveFile=$2
    local lastLineNumber=$3
    local displayLines=$4
    local datetime=$5

    if [[ -n "$saveFile" && -e $saveFile ]]; then 
        echo "# Last Line: $lastLineNumber - Display Total Lines: $displayLines - $datetime - $logFile" >> $saveFile;
    fi

    # If no display line, then hide the save file
    if [[ $displayLines -eq 0 && -n "$saveFile" && -e $saveFile ]]; then
        currentSaveName=${saveFile##*/}
        currentSavePath=${saveFile%/*}
        hiddenSaveFile="$currentSavePath/.$currentSaveName"
        mv $saveFile $hiddenSaveFile
    fi
}

# Get last line number that the job had searched last executed
function getLastLineNumber()
{
    local logFile=$1
    local saveFile=$2
    local lastLineNumber=0
    local tmpSaveFile=$saveFile

    local getFromSaveFile=0
    if [ $followFlag = 1 ]; then
        if [[ -n "${followData["$logFile,lastLineNumber"]}" ]]; then
            lastLineNumber=${followData["$logFile,lastLineNumber"]}
        else
            # First time of --follow, will try to get from save file
            getFromSaveFile=1
        fi
    else
        getFromSaveFile=1
    fi

    if [ $getFromSaveFile = 1 ]; then
        if [ -n "$tmpSaveFile" ]; then
            if [ -e $tmpSaveFile ]; then
                lastLine=`tail -n 1 $tmpSaveFile`
                if [ -z "$lastLine" ]; then
                    tmpSaveName=${tmpSaveFile##*/}
                    tmpSavePath=${tmpSaveFile%/*}
                    tmpSaveFile="$tmpSavePath/.$tmpSaveName"
                    if [ -e $tmpSaveFile ]; then
                        lastLine=`tail -n 1 $tmpSaveFile`
                    fi
                fi
                # echo -e "\033[32mLast Line: $lastLine\033[0m"
                if [ -n "$lastLine" ]; then
                    lastLineReg="\# Last Line: ([0-9]+) "
                    if [[ $lastLine =~ $lastLineReg ]]; then
                        lastLineNumber=${BASH_REMATCH[1]}
                    fi
                fi
            fi
        fi
    fi

    # echo -e "\033[32mLast Line Number: $lastLineNumber\033[0m"
    echo $lastLineNumber
}

# Get total lines that the job had searched last executed
function getLastDisplayTotalLines()
{
    local logFile=$1
    local saveFile=$2
    local lastLines=0

    local getFromSaveFile=0
    if [ $followFlag = 1 ]; then
        if [[ -n "${followData["$logFile,displayLines"]}" ]]; then
            lastLines=${followData["$logFile,displayLines"]}
        else
            # First time of --follow, will try to get from save file
            getFromSaveFile=1
        fi
    else
        getFromSaveFile=1
    fi

    if [ $getFromSaveFile = 1 ]; then
        if [[ -n "$saveFile" && -e $saveFile ]]; then 
            lastLine=`tail -n 1 $saveFile`
            # echo -e "\033[32mLast Line: $lastLine\033[0m"
            if [ -n "$lastLine" ]; then
                lastLineReg="Display Total Lines: ([0-9]+) "
                if [[ $lastLine =~ $lastLineReg ]]; then
                    lastLines=${BASH_REMATCH[1]}
                fi
            fi
        fi
    fi

    # echo -e "\033[32mLast Line Number: $lastLines\033[0m"
    echo $lastLines
}

# Display log file lines if user need it
# The line must match $matchReg user set and after the $startDatetime
function displayFile()
{
    local logFile=$1
    
    isAllowedFileChecker $logFile
    isAllowedFileFlag=`echo $?`
    if [ $isAllowedFileFlag -eq 0 ]; then
        # echo "Expired file!"
        return 0
    fi

    echoMsg "\033[4;36m# Log File: $logFile\033[0m" $FLAG_NOT_FOLLOW

    local saveFile=""
    if [ $isSaveLogs -eq 1 ]; then
        saveFile=$(createSaveFile $logFile)
        echoMsg "\033[4;36m# Save File: $saveFile\033[0m" $FLAG_NOT_FOLLOW
    else
        saveFile=""
    fi

    local lastLineNumber=$(getLastLineNumber $logFile "$saveFile")

    local currentLineNumber=0
    local isAllowedLineFlag=0
    local noCheckLineOffset=0
    local noCheckLineNumber=0
    displayTotalLines=$(getLastDisplayTotalLines $logFile "$saveFile")
    while read -r line
    do
        ((currentLineNumber++))

        # Ignore the line which is less than the last line that we executed last time
        if [ $currentLineNumber -le $lastLineNumber ]; then
            continue
        fi

        # If a line is allowed to display, then all the lines after it is allowed to display
        if [ $isAllowedLineFlag -eq 0 ]; then
            # Check if the line is allowed to display
            # line has space, so need to add ""
            isAllowedLineChecker "$line"
            isAllowedLineFlag=`echo $?`

            if [ $isAllowedLineFlag -eq 0 ]; then
                continue
            fi
        fi

        displayLine "$line" $currentLineNumber $noCheckLineNumber "$saveFile"
        noCheckLineOffset=`echo $?`
        noCheckLineNumber=$((currentLineNumber+noCheckLineOffset))

    done < $logFile

    displayDetails $logFile $currentLineNumber "$saveFile" $displayTotalLines
}

# Display log files one by one
function displayFiles()
{
    for logFile in $logFiles
    do
        displayFile $logFile
    done
}

# Delete the save path
function removeSavePath()
{
    if [ $savePath = "/" ]; then
        echo -e "\033[1;31mCan not delete /\033[0m"
        exit 1
    fi
    if [[ -e $savePath ]]; then
        rm -rf $savePath
        echo -e "\033[1;32mDeleted!\033[0m"
    else
        echo -e "\033[1;31mPath not existed!\033[0m"
    fi
}

# Delete the save path and exit
function clean()
{
    echo -e "\033[1;33mClean save logs...\033[0m"
    removeSavePath
    exit
}

# Delete the save path and search logs
function reset()
{
    echo -e "\033[1;33mReset save logs...\033[0m"
    removeSavePath
}

# Save the log files data 
# Format:
#  followData["$logFile,lastLineNumber"]=$lastLineNumber
#  followData["$logFile,displayLines"]=$displayLines
#  followData["$logFile,datetime"]=$datetime
declare -A followData
# For easilly to know how many log files we have followed
# Format:
# followFiles["$logFile"]=$saveFile
declare -A followFiles
function setFollowData()
{
    if [ $followFlag = 1 ]; then
        followData["$1,lastLineNumber"]=$2
        followData["$1,displayLines"]=$3
        followData["$1,datetime"]=$4
        followFiles["$1"]=$5
    fi
}

# Persist the log file details before exit
# Because we don't persist this if --follow
function persistFollowData()
{
    local logFile=""
    local saveFile=""
    local lastLineNumber=0
    local displayLines=0
    local datetime=""

    for logFile in "${!followFiles[@]}"
    do
        saveFile="${followFiles[$logFile]}"

        lastLineNumber=${followData["$logFile,lastLineNumber"]}
        if [[ -n $lastLineNumber ]]; then
            displayLines=${followData["$logFile,displayLines"]}
            datetime=${followData["$logFile,datetime"]}
            # echo -e "\033[4;36m# Last Line: $lastLineNumber - Display Total Lines: $displayLines - $datetime - $logFile\033[0m"

            persistDetailsToSaveFile $logFile "$saveFile" $lastLineNumber $displayLines "$datetime"
        fi
    done
}

# If --follow, we don't exit
# To not stop when end of log files is reached, but rather to wait for additional data to be appended to the log files
function follow()
{
    # followCount=1
    local nMinute=0
    # --mmin 0 means the log files must be modified in 60 seconds
    local findCommandFollow="$findCommand -mmin $nMinute"
    # echo $findCommandFollow

    if [ $followFlag = 1 ]; then
        while true
        do
            sleep $followInterval

            logFiles=`$findCommandFollow`
            logFilesArray=($logFiles)
            logFilesCount=${#logFilesArray[*]}

            if [ $logFilesCount -eq 0 ]; then
                # echo -e "\033[1;31m$followCount:No log file found!\033[0m"
                continue
            fi

            # echo -e "$followCount:Log Files Total Count: \033[1;32m$logFilesCount\033[0m"

            for logFile in $logFiles
            do
                # echo "$logFile"
                displayFile $logFile
            done

            # ((followCount++))
        done
    fi
}

# Ctrl + C Stop the shell
# If --follow, we must not exit immediately the shell and must add the log file details into save files before exited
function trapINT()
{
    echo "Exiting..."
    echo -e "\033[93mPersisting the log file details into save files before exit\033[0m"
    echo -e "\033[93mPlease don't exit again, will exit it after persisting\033[0m"
    persistFollowData
    echo -e "Exited!"
    exit
}

# Delete save files and exit
if [[ $isClean -eq 1 ]]; then clean; fi

# Only delete save files
if [[ $isReset -eq 1 ]]; then reset; fi

pathWithoutEndSlash=${path%/}

findCommand="find $path -name $name $findOpts"

echo -e "\033[1;32mStart searching logs...\033[0m"
echo -e "\033[1;32m> $findCommand\033[0m"
logFiles=`$findCommand`
logFilesArray=($logFiles)
logFilesCount=${#logFilesArray[*]}

if [ $logFilesCount -eq 0 ]; then
    echo -e "\033[1;31mNo log file found!\033[0m"
    if [ $followFlag = 0 ]; then exit 0; fi
fi

echo -e "Log Files Total Count: \033[1;32m$logFilesCount\033[0m"
echo -e "> Search the logs write after \033[1;32m$startDatetime\033[0m"
echo -e "> Search the lines of log files that match \033[1;32m$matchReg\033[0m"

if [ $followFlag = 1 ]; then trap trapINT SIGINT; fi

displayFiles

follow