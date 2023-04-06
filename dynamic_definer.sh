#!/usr/bin/env bash
# Replace !/bin/bash, because Mac `brew install bash`, the bash is /usr/local/bin/bash, not /bin/bash

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
