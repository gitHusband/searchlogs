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
  --file-time-reg           If match datetime of the log files name with reg, then display the file if checking datetime success
                            If empty regs, then display all the files
                            - Option Format: reg1,format1,reg2,format2
                                reg1/reg2: Match datetime of the log files name
                                format1/format2: File datetime format, use it to convert matched datetime string to timestamp
  --line-time-reg           If match datetime of a line of log file, then display the file if checking datetime success
                            If empty regs, then display all the lines
                            - Option Format: reg1,format1,reg2,format2
                                reg1/reg2: Match datetime of a line of log file
                                format1/format2: Line datetime format, use it to convert matched datetime string to timestamp
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

os=$(getOS)

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

function defaultDateToTime()
{
    local defaultDateTimeStr=$1
    local timestamp=0

    if [ $os = "mac" ]; then
        timestamp=`date -j -f "%Y-%m-%d %H:%M:%S" "$defaultDateTimeStr" +%s` # Mac
    else
        timestamp=`date -d "$defaultDateTimeStr" +%s` # Linux
    fi

    echo $timestamp
}

# Here is an example of how to auto convert date to timestamp
# generateAutoDateCompleteFuncBody is depend on this
function autoFileDateCompleteExample()
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

    # echo "@ Auto datetime complete: $fileDatetimeFormat - $fileDatetime"
}

# Generate the body of a function which can auto convert date to timestamp for file or line
# Example: see function autoFileDateCompleteExample
function generateAutoDateCompleteFuncBody()
{
    local type=$1

    local funcBody="
        # Todo: Complete the datetime.
        # Here are the global variables you need
        # fileDatetime - The datetime matched by file datetime reg
        # fileDatetimeFormat - The current file datetime format when traversing ile-time-reg
        # fileDatetimeReg - The current file datetime reg when traversing ile-time-reg

        datetimeCompletion['%Y']='2023'
        datetimeCompletion['%m']='04'
        datetimeCompletion['%d']='01'
        datetimeCompletion['%H']='23'
        datetimeCompletion['%M']='59'
        datetimeCompletion['%S']='59'

        while IFS= read -r -d '' -n 1 c; do
            case \$c in
                %)
                    continue
                    ;;
                Y|m|d|H|M|S)
                    datetimeCompletion[\"%\$c\"]=\${${type}Datetime:0:\${datetimeOptLength[\"%\$c\"]}}
                    ${type}Datetime=\${${type}Datetime:\${datetimeOptLength[\"%\$c\"]}}
                    ;;
                *)
                    ${type}Datetime=\${${type}Datetime:1}}
            esac
        done < <(printf '%s' \"\$${type}DatetimeFormat\")

        ${type}DatetimeFormat=\"%Y-%m-%d %H:%M:%S\"
        ${type}Datetime=\"\${datetimeCompletion[%Y]}-\${datetimeCompletion[%m]}-\${datetimeCompletion[%d]} \${datetimeCompletion[%H]}:\${datetimeCompletion[%M]}:\${datetimeCompletion[%S]}\"

        # echo \"@ Auto datetime complete: \$${type}DatetimeFormat - \$${type}Datetime\"
    "

    echo "$funcBody"
}

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

declare -A fileDateCompleteHandlers
declare -A lineDateCompleteHandlers

# Convert file/line date to time
# If you have special date format which `date` command can not convert, you can overloaded the datetimeComplete function by yourself
if [ $os = "mac" ]; then

    function fileDateToTime()
    {
        # echo "@ fileDateToTime($os): $fileDatetimeFormat - $fileDatetime"

        # Call file date complete function
        ${fileDateCompleteHandlers["$fileDatetimeFormat"]}

        fileTimestamp=`date -j -f "$fileDatetimeFormat" "$fileDatetime" +%s` # Mac

        # echo "FILE: date -j -f "$fileDatetimeFormat" "$fileDatetime" +%s ======> $fileTimestamp"
    }

    function lineDateToTime()
    {
        # echo "@ lineDateToTime($os): $lineDatetimeFormat - $lineDatetime"

        # Call line date complete function
        ${lineDateCompleteHandlers["$lineDatetimeFormat"]}

        lineTimestamp=`date -j -f "$lineDatetimeFormat" "$lineDatetime" +%s` # Mac

        # echo "LINE: date -j -f "$lineDatetimeFormat" "$lineDatetime" +%s ======> $lineTimestamp"
    }

    # Call this definer after setting file/line time reg(--file-time-reg/--line-time-reg)
    # Define file/line date complete function
    # Why need date complete function in Mac?
    # Because Mac `date` command wull auto set the time "%H:%M:%S" to the current time if don't set this time format
    # We need to set "%H:%M:%S" to "23:59:59", not current time if don't set "%H:%M:%S"
    function dateCompleteDefiner()
    {
        local dateFormat=$1
        # file or line
        local type=$2

        dateFormatBase64=$(echo "$dateFormat" | base64)
        # funcSuffix=${dateFormatBase64%%\=*}
        funcSuffix=${dateFormatBase64//\=/_}
        funcName=${type}DateComplete$funcSuffix
        funcBody=""
        # echo "@ ${type}dateCompleteDefiner($os) - funcName($funcName) - $dateFormat: $dateFormatBase64 - $funcSuffix"

        case $dateFormat in
            "%Y-%m-%d %H:%M:%S"|"%Y%m%d %H:%M:%S"|"%Y%m%d%H%M%S"|"%Y%m%d_%H:%M:%S")
                # Do nothing
                funcBody="
                    return 0
                "
                ;;
            "%Y-%m-%d"|"%Y%m%d"|"%d%m%Y"|"%d/%m/%Y"|"%m/%d/%Y")
                funcBody="
                    # The end time of the date
                    ${type}Datetime=\"\$${type}Datetime 23:59:59\"
                    ${type}DatetimeFormat=\"\$${type}DatetimeFormat %H:%M:%S\"
                "
                ;;
            *)
                funcBody=$(generateAutoDateCompleteFuncBody "$type")
        esac

        if [ -n "$funcBody" ]; then
            eval "${funcName}() { ${funcBody} }"
            eval "${type}DateCompleteHandlers[\"\$dateFormat\"]=$funcName"
        fi
    }

else

    function fileDateToTime()
    {
        # echo "@ fileDateToTime($os): $fileDatetimeFormat - $fileDatetime"

        # Call file date complete function
        ${fileDateCompleteHandlers["$fileDatetimeFormat"]}

        fileTimestamp=`date -d "$fileDatetime" +%s` # Linux

        # echo "FILE: date -d "$fileDatetime" +%s ======> $fileTimestamp"
    }

    function lineDateToTime()
    {
        # echo "@ lineDateToTime($os): $lineDatetimeFormat - $lineDatetime"

        # Call line date complete function
        ${lineDateCompleteHandlers["$lineDatetimeFormat"]}

        lineTimestamp=`date -d "$lineDatetime" +%s` # Linux

        # echo "LINE: date -d "$lineDatetime" +%s ======> $lineTimestamp"
    }

    # Call this definer after setting file/line time reg(--file-time-reg/--line-time-reg)
    # Define file/line date complete function
    # Why need date complete function in Linux?
    # Because Linux `date` command do NOT support special date format, such as "%Y%m%d", must turn it to "%Y-%m-%d"
    function dateCompleteDefiner()
    {
        local dateFormat=$1
        # file or line
        local type=$2

        dateFormatBase64=$(echo "$dateFormat" | base64)
        # funcSuffix=${dateFormatBase64%%\=*}
        funcSuffix=${dateFormatBase64//\=/_}
        funcName=${type}DateComplete$funcSuffix
        funcBody=""
        # echo "@ ${type}dateCompleteDefiner($os) - funcName($funcName) - $dateFormat: $dateFormatBase64 - $funcSuffix"

        case $dateFormat in
            "%Y-%m-%d %H:%M:%S")
                # Do nothing
                funcBody="
                    return 0
                "
                ;;
            "%Y-%m-%d"|"%Y/%m/%d")
                funcBody="
                    day=\${${type}Datetime:0-2}
                    month=\${${type}Datetime:5:2}
                    year=\${${type}Datetime:0:4}
                    ${type}Datetime=\"\$year-\$month-\$day\"

                    # The end time of the date
                    ${type}Datetime=\"\$${type}Datetime 23:59:59\"

                    # echo \"@ ${type}DateComplete(\$os): \$${type}Datetime - \$${type}DatetimeFormat\";
                "
                ;;
            "%Y%m%d")
                funcBody="
                    day=\${${type}Datetime:0-2}
                    month=\${${type}Datetime:4:2}
                    year=\${${type}Datetime:0:4}
                    ${type}Datetime=\"\$year-\$month-\$day\"

                    # The end time of the date
                    ${type}Datetime=\"\$${type}Datetime 23:59:59\"

                    # echo \"@ ${type}DateComplete(\$os): \$${type}Datetime - \$${type}DatetimeFormat\";
                "
                ;;
            *)
                funcBody=$(generateAutoDateCompleteFuncBody "$type")
        esac

        if [ -n "$funcBody" ]; then
            eval "${funcName}() { ${funcBody} }"
            eval "${type}DateCompleteHandlers[\"\$dateFormat\"]=$funcName"
        fi
    }
fi

# Define file date to time function for each datetime format which set by --file-time-reg
function fileDateCompleteDefiners()
{
    # Don't have to define date complete function if no regs
    if [[ $fileDatetimeRegsLength -eq 0 ]]; then return 0; fi

    fileDatetimeReg=""
    fileDatetimeFormat=""

    local fileDatetimeRegIndex=0
    while ((fileDatetimeRegIndex < $fileDatetimeRegsLength))
    do
        fileDatetimeReg="${fileDatetimeRegs[$fileDatetimeRegIndex]}"
        ((fileDatetimeRegIndex++))
        fileDatetimeFormat="${fileDatetimeRegs[$fileDatetimeRegIndex]}"
        
        # Define a handler of how to convert date string to timestamp
        dateCompleteDefiner "$fileDatetimeFormat" "file"

        ((fileDatetimeRegIndex++))
    done

    return 1
}

# Define line date to time function for each datetime format which set by --line-time-reg
function lineDateCompleteDefiners()
{
    # Don't have to define date complete function if no regs
    if [[ $lineDatetimeRegsLength -eq 0 ]]; then return 0; fi

    lineDatetimeReg=""
    lineDatetimeFormat=""

    local lineDatetimeRegIndex=0
    while ((lineDatetimeRegIndex < $lineDatetimeRegsLength))
    do
        lineDatetimeReg="${lineDatetimeRegs[$lineDatetimeRegIndex]}"
        ((lineDatetimeRegIndex++))
        lineDatetimeFormat="${lineDatetimeRegs[$lineDatetimeRegIndex]}"
        
        # Define a handler of how to convert date string to timestamp
        dateCompleteDefiner "$lineDatetimeFormat" "line"

        ((lineDatetimeRegIndex++))
    done

    return 1
}

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
    fileDatetime=""
    fileTimestamp=0

    # If empty fileDatetimeReg, then display all the files
    if [[ -z "$fileDatetimeReg" ]]; then return 0; fi
    
    if [[ "$file" =~ $fileDatetimeReg ]]; then
        fileDatetime=${BASH_REMATCH[1]}
        
        fileDateToTime
        if [ $fileTimestamp -ge $startTimestamp ]; then
            # Display this file
            return 0
        else
            # Don't display this file
            return 2
        fi
    fi

    # Will try to match other regs
    # If not more reg, then don't display this line
    return 1
}

function isAllowedFileCheckers()
{
    # Allowed if no regs
    if [[ $fileDatetimeRegsLength -eq 0 ]]; then return 0; fi

    fileDatetimeReg=""
    fileDatetimeFormat=""
    local isNotAllowedFileFlag=1

    local fileDatetimeRegIndex=0
    while ((fileDatetimeRegIndex < $fileDatetimeRegsLength))
    do
        fileDatetimeReg="${fileDatetimeRegs[$fileDatetimeRegIndex]}"
        ((fileDatetimeRegIndex++))
        fileDatetimeFormat="${fileDatetimeRegs[$fileDatetimeRegIndex]}"
        
        isAllowedFileChecker
        isNotAllowedFileFlag=`echo $?`
        if [ $isNotAllowedFileFlag -eq 0 ]; then
            return 0
        elif [ $isNotAllowedFileFlag -eq 2 ]; then
            return 2
        fi
        ((fileDatetimeRegIndex++))
    done

    return 1
}

# Check if a line is allowed to dislpay
function isAllowedLineChecker()
{
    lineDatetime=""
    lineTimestamp=0

    # If empty lineDatetimeReg, then display all the lines
    if [[ -z "$lineDatetimeReg" ]]; then return 0; fi

    if [[ $line =~ $lineDatetimeReg ]]; then
        lineDatetime=${BASH_REMATCH[1]}

        lineDateToTime
        if [ $lineTimestamp -ge $startTimestamp ]; then
            # Display this line
            return 0
        else
            # Don't display this line
            return 2
        fi
    fi

    # Will try to match other regs
    # If not more reg, then don't display this line
    return 1
}

function isAllowedLineCheckers()
{
    # Allowed if no regs
    if [[ $lineDatetimeRegsLength -eq 0 ]]; then return 0; fi

    lineDatetimeReg=""
    lineDatetimeFormat=""
    local isNotAllowedLineFlag=1

    local lineDatetimeRegIndex=0
    while ((lineDatetimeRegIndex < $lineDatetimeRegsLength))
    do
        lineDatetimeReg="${lineDatetimeRegs[$lineDatetimeRegIndex]}"
        ((lineDatetimeRegIndex++))
        lineDatetimeFormat="${lineDatetimeRegs[$lineDatetimeRegIndex]}"
        isAllowedLineChecker
        isNotAllowedLineFlag=`echo $?`
        if [ $isNotAllowedLineFlag -eq 0 ]; then
            return 0
        elif [ $isNotAllowedLineFlag -eq 2 ]; then
            return 2
        fi
        ((lineDatetimeRegIndex++))
    done

    return 1
}

# It's allowed to display line without check if the line number is less than ((matchLineNumber+noCheckLineOffset))
function getLineOffset()
{
    local line=$1
    local lineOffset=0
    local lineOffsetRegIndex=0
    while ((lineOffsetRegIndex < $lineOffsetRegsLength))
    do
        # echo "$lineOffsetRegIndex - ${lineOffsetRegs[$lineOffsetRegIndex]}"
        if [[ $line =~ ${lineOffsetRegs[$lineOffsetRegIndex]} ]]; then
            # echo -e "\033[33m  ${BASH_REMATCH[1]}\033[0m"
            ((lineOffsetRegIndex++))
            # echo "#$lineOffsetRegIndex ${lineOffsetRegs[$lineOffsetRegIndex]}"
            lineOffset=${lineOffsetRegs[$lineOffsetRegIndex]}
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
    local lineNumber=$1
    local noCheckLineNumber=$2

    local noCheckLineOffset=0

    # Display line without check if the line number is less than noCheckLineNumber
    if [ $lineNumber -le $noCheckLineNumber ]; then
        ((displayTotalLines++))
        echo -e "\033[33m$line\033[0m"
        if [[ -n "$saveFile" && -e "$saveFile" ]]; then echo "$line" >> "$saveFile"; fi
        return $((noCheckLineNumber - lineNumber))
    fi

    if [[ $line =~ $matchReg ]]; then
        ((displayTotalLines++))
        echo -e "\033[32m$lineNumber:$line\033[0m"
        if [[ -n "$saveFile" && -e "$saveFile" ]]; then echo "$lineNumber:$line" >> "$saveFile"; fi
        # noCheckLineOffset=0
        getLineOffset "$line"
        noCheckLineOffset=`echo $?`
    fi

    return $noCheckLineOffset
}

# Create save file if need to save file
function createSaveFile()
{
    local file=$1
    local saveFile=${file/$pathWithoutEndSlash/$savePath}
    saveFile=$saveFile$saveNameSuffix

    # saveName=${saveFile##*/}
    local currentSavePath=${saveFile%/*}

    if [ ! -e $currentSavePath ]; then
        mkdir -p $currentSavePath
    fi

    if [ ! -e "$saveFile" ]; then
        touch "$saveFile"
    fi

    echo $saveFile;
}

# Display "last line number"/"total lines"/"datetime" of log file
# If save log, then save the "last line number"/"total lines"/"datetime" into save file
function displayDetails()
{
    local lastLineNumber=$1
    local displayLines=$2

    datetime=`date +"%Y-%m-%d %H:%M:%S"`

    echoMsg "\033[4;36m# Last Line: $lastLineNumber - Display Total Lines: $displayLines - $datetime - $file\033[0m\n" $FLAG_NOT_FOLLOW

    if [ $followFlag = 1 ]; then
        # If follow new lines, display to terminal to know which file is the line belong to
        if [ -z "${followData["$file,displayLines"]}" ] || [[ -n "${followData["$file,displayLines"]}" && $displayLines -gt ${followData["$file,displayLines"]} ]]; then
            echo -e "\033[4;36m# Last Line: $lastLineNumber - Display Total Lines: $displayLines - $datetime - $file\033[0m\n"
        fi
    else
        persistDetailsToSaveFile "$file" "$saveFile" $lastLineNumber $displayLines "$datetime"
    fi

    setFollowData "$file" $lastLineNumber $displayLines "$datetime" "$saveFile"
}

# Persist details to the end of the save file
function persistDetailsToSaveFile()
{
    local file=$1
    local saveFile=$2
    local lastLineNumber=$3
    local displayLines=$4
    local datetime=$5

    if [[ -n "$saveFile" && -e $saveFile ]]; then 
        echo "# Last Line: $lastLineNumber - Display Total Lines: $displayLines - $datetime - $file" >> "$saveFile";
    fi

    # If no display line, then hide the save file
    if [[ $displayLines -eq 0 && -n "$saveFile" && -e $saveFile ]]; then
        currentSaveName=${saveFile##*/}
        currentSavePath=${saveFile%/*}
        hiddenSaveFile="$currentSavePath/.$currentSaveName"
        mv "$saveFile" "$hiddenSaveFile"
    fi
}

# Get last line number that the job had searched last executed
function getLastLineNumber()
{
    local file=$1
    local saveFile=$2
    local lastLineNumber=0
    local tmpSaveFile=$saveFile

    local getFromSaveFile=0
    if [ $followFlag = 1 ]; then
        if [[ -n "${followData["$file,lastLineNumber"]}" ]]; then
            lastLineNumber=${followData["$file,lastLineNumber"]}
        else
            # First time of --follow, will try to get from save file
            getFromSaveFile=1
        fi
    else
        getFromSaveFile=1
    fi

    if [ $getFromSaveFile = 1 ]; then
        if [ -n "$tmpSaveFile" ]; then
            if [ -e "$tmpSaveFile" ]; then
                lastLine=`tail -n 1 "$tmpSaveFile"`
                if [ -z "$lastLine" ]; then
                    tmpSaveName=${tmpSaveFile##*/}
                    tmpSavePath=${tmpSaveFile%/*}
                    tmpSaveFile="$tmpSavePath/.$tmpSaveName"
                    if [ -e "$tmpSaveFile" ]; then
                        lastLine=`tail -n 1 "$tmpSaveFile"`
                    fi
                fi
                # echo -e "\033[32mLast Line: $lastLine\033[0m"
                if [ -n "$lastLine" ]; then
                    lastLineReg="# Last Line: ([0-9]+) "
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
    local file=$1
    local saveFile=$2
    local lastLines=0

    local getFromSaveFile=0
    if [ $followFlag = 1 ]; then
        if [[ -n "${followData["$file,displayLines"]}" ]]; then
            lastLines=${followData["$file,displayLines"]}
        else
            # First time of --follow, will try to get from save file
            getFromSaveFile=1
        fi
    else
        getFromSaveFile=1
    fi

    if [ $getFromSaveFile = 1 ]; then
        if [[ -n "$saveFile" && -e $saveFile ]]; then 
            lastLine=`tail -n 1 "$saveFile"`
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
    isAllowedFileCheckers
    local isNotAllowedFileFlag=`echo $?`
    if [ ! $isNotAllowedFileFlag -eq 0 ]; then
        # echo "Expired file!"
        return 1
    fi

    echoMsg "\033[4;36m# Log File: $file\033[0m" $FLAG_NOT_FOLLOW

    saveFile=""
    if [ $isSaveLogs -eq 1 ]; then
        saveFile=$(createSaveFile "$file")
        echoMsg "\033[4;36m# Save File: $saveFile\033[0m" $FLAG_NOT_FOLLOW
    else
        saveFile=""
    fi

    local lastLineNumber=$(getLastLineNumber "$file" "$saveFile")

    local currentLineNumber=0
    local isNotAllowedLineFlag=1
    local noCheckLineOffset=0
    local noCheckLineNumber=0
    displayTotalLines=$(getLastDisplayTotalLines "$file" "$saveFile")
    while IFS=$'\n' read -r line
    do
        ((currentLineNumber++))

        # Ignore the line which is less than the last line that we executed last time
        if [ $currentLineNumber -le $lastLineNumber ]; then
            continue
        fi

        # If a line is allowed to display, then all the lines after it is allowed to display
        if [ ! $isNotAllowedLineFlag -eq 0 ]; then
            # Check if the line is allowed to display
            isAllowedLineCheckers
            isNotAllowedLineFlag=`echo $?`
            if [ ! $isNotAllowedLineFlag -eq 0 ]; then
                continue
            fi
        fi

        displayLine $currentLineNumber $noCheckLineNumber
        noCheckLineOffset=`echo $?`
        noCheckLineNumber=$((currentLineNumber+noCheckLineOffset))

    done < "$file"

    displayDetails $currentLineNumber $displayTotalLines
}

# Display log files one by one
function displayFiles()
{
    while read -r file
    do
        displayFile
    done <<< "$files"
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
#  followData["$file,lastLineNumber"]=$lastLineNumber
#  followData["$file,displayLines"]=$displayLines
#  followData["$file,datetime"]=$datetime
declare -A followData
# For easilly to know how many log files we have followed
# Format:
# followFiles["$file"]=$saveFile
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
    local file=""
    local saveFile=""
    local lastLineNumber=0
    local displayLines=0
    local datetime=""

    for file in "${!followFiles[@]}"
    do
        saveFile="${followFiles[$file]}"

        lastLineNumber=${followData["$file,lastLineNumber"]}
        if [[ -n "$lastLineNumber" ]]; then
            displayLines=${followData["$file,displayLines"]}
            datetime=${followData["$file,datetime"]}
            # echo -e "\033[4;36m# Last Line: $lastLineNumber - Display Total Lines: $displayLines - $datetime - $file\033[0m"

            persistDetailsToSaveFile "$file" "$saveFile" $lastLineNumber $displayLines "$datetime"
        fi
    done
}

# If --follow, we don't exit
# To not stop when end of log files is reached, but rather to wait for additional data to be appended to the log files
function follow()
{
    # followCount=1
    local nMinute=0
    if [ $os = "mac" ]; then nMinute=1; fi
    # Find the log files modified in 60 seconds
    local findCommandFollow="$findCommand -mmin $nMinute"
    # echo $findCommandFollow

    if [ $followFlag = 1 ]; then
        while true
        do
            sleep $followInterval

            files=`$findCommandFollow`
            readarray -t filesArray <<<"$files"
            # filesArray=($files)
            filesCount=${#filesArray[*]}

            if [ $filesCount -eq 0 ]; then
                # echo -e "\033[1;31m$followCount:No log file found!\033[0m"
                continue
            fi

            # echo -e "$followCount:Log Files Total Count: \033[1;32m$filesCount\033[0m"

            while read -r file
            do
                displayFile
            done <<< "$files"

            # ((followCount++))
        done
    fi
}

# Ctrl + C Stop the shell
# If --follow, we must not exit immediately the shell and must add the log file details into save files before exited
function trapPersistFollowData()
{
    echo -e "\nExiting..."
    echo -e "\033[93mPersisting the log file details into save files before exit\033[0m"
    echo -e "\033[93mPlease don't exit again, will exit it after persisting\033[0m"
    persistFollowData
    echo -e "Exited!"
    exit
}

# Set By Option: -p, --path
# Find log files in here
path=`pwd`
# Set By Option: -n, --name
# Regular expression of log file name
name='*.log'
# Set By Option: -s, --start-datetime
# Search the logs write after this time
startDatetime=$(getDefaultDatetime)
startTimestamp=$(defaultDateToTime "$startDatetime")
# Set By Option: -m, --match-reg
# Search the lines of log files that match this regular expression
matchReg="^ERROR|WARNING|CRITICAL"
# Set By Option: --find-opts
# Options of command find
findOpts=""
# Set By Option: --save-log
# Save logs that searched
isSaveLogs=0
# Set By Option: --save-path
# Save logs file path
savePath="`pwd`/searchlogs_result"
# No option
# Save file name suffix
saveNameSuffix='.search'
# Set By Option: -c, --clean
# Clean the save logs and exit
isClean=0
# Set By Option: --reset
# Clean the save logs and then search logs
isReset=0
# Set By Option: --line-offset-reg
# It's allowed to display line without check if the line number is less than ((matchLineNumber+noCheckLineOffset))
# - Set noCheckLineOffset if the line matches reg
# - Option Format: reg1,noCheckLineOffset1,reg2,noCheckLineOffset2
lineOffsetRegs=("^CRITICAL" 5 "Unexpected Exception" 6 "Debug backtrace" 6 "session data" 5)
lineOffsetRegsLength=${#lineOffsetRegs[@]}
# Set By Option: --file-time-reg
# If match datetime of the log files name with reg, then display the file if checking datetime success
# If empty regs, then display all the files
# - Option Format: reg1,format1,reg2,format2
#   reg1/reg2: Match datetime of the log files name
#   format1/format2: File datetime format, use it to convert matched datetime string to timestamp
fileDatetimeRegs=(
    "^.*/.*([0-9]{4}-[0-9]{2}-[0-9]{2})" "%Y-%m-%d"
    "^.*/.*([0-9]{8})" "%Y%m%d"
)
fileDatetimeRegsLength=${#fileDatetimeRegs[@]}
# Set By Option: --line-time-reg
# If match datetime of a line of log file, then display the file if checking datetime success
# If empty regs, then display all the lines
# - Option Format: reg1,format1,reg2,format2
#   reg1/reg2: Match datetime of a line of log file
#   format1/format2: Line datetime format, use it to convert matched datetime string to timestamp
lineDatetimeRegs=(
    "([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})" "%Y-%m-%d %H:%M:%S"
)
lineDatetimeRegsLength=${#lineDatetimeRegs[@]}
# Set By Option: -f, --follow 
# If set to 1, means to not stop when end of log files is reached, but rather to wait for additional data to be appended to the log files
followFlag=0
# No option
# Follow interval, default to 3 seconds
followInterval=3

# Sopport custom config
if [ -e ./config.sh ]; then echo 123; source ./config.sh; fi

# Export functions for other shell calling
isExport=0

shortOpts="hp:n:s:m:fc"
longOpts="help,path:,name:,start-datetime:,match-reg:,find-opts:,save-log,save-path:,line-offset-reg:,file-time-reg:,line-time-reg:,follow,clean,reset,export"
getoptCmd=$(getopt -o $shortOpts -l "$longOpts" -n "$0" -- "$@")
[ $? -ne 0 ] && { echo "Try '$0 --help' for more information."; exit 1; }

eval set -- "$getoptCmd"
while true; do
    case "$1" in
        -h|--help) help $0;exit 0;;
        -p|--path) path=$2;shift;;
        -n|--name) name=$2;shift;;
        -s|--start-datetime) startDatetime=$2;startTimestamp=$(defaultDateToTime "$startDatetime");shift;;
        -m|--match-reg) matchReg=$2;shift;;
        --find-opts) findOpts=$2;shift;;
        --save-log) isSaveLogs=1;;
        --save-path) savePath="$2/searchlogs_result";shift;;
        -c|--clean) isClean=1;;
        --reset) isReset=1;;
        --line-offset-reg) IFS=',' read -ra lineOffsetRegs <<< "$2";lineOffsetRegsLength=${#lineOffsetRegs[@]};shift;;
        --file-time-reg) IFS=',' read -ra fileDatetimeRegs <<< "$2";fileDatetimeRegsLength=${#fileDatetimeRegs[@]};shift;;
        --line-time-reg) IFS=',' read -ra lineDatetimeRegs <<< "$2";lineDatetimeRegsLength=${#lineDatetimeRegs[@]};shift;;
        -f|--follow) followFlag=1;;
        --export) isExport=1;;
        --) shift; break;;
        *) echo "$1 $2 is not supported";exit 1;;
    esac
    shift
done

# Export functions for other shell calling
if [[ $isExport -eq 1 ]]; then return 0; fi

# Delete save files and exit
if [[ $isClean -eq 1 ]]; then clean; fi

# Only delete save files
if [[ $isReset -eq 1 ]]; then reset; fi

# Define file date to time function for each datetime format which set by --file-time-reg
fileDateCompleteDefiners
# Define line date to time function for each datetime format which set by --line-time-reg
lineDateCompleteDefiners

pathWithoutEndSlash=${path%/}

findCommand="find $path -name $name $findOpts"

echo -e "\033[1;32mStart searching logs...\033[0m"
echo -e "\033[1;32m> $findCommand\033[0m"
files=`$findCommand`
readarray -t filesArray <<<"$files"
filesCount=${#filesArray[*]}

if [ $filesCount -eq 0 ]; then
    echo -e "\033[1;31mNo log file found!\033[0m"
    if [ $followFlag = 0 ]; then exit 0; fi
fi

echo -e "Log Files Total Count: \033[1;32m$filesCount\033[0m"
echo -e "> Search the logs write after \033[1;32m$startDatetime\033[0m"
echo -e "> Search the lines of log files that match \033[1;32m$matchReg\033[0m"

if [ $followFlag = 1 ]; then
    trap trapPersistFollowData SIGINT SIGTERM;
fi

displayFiles

follow