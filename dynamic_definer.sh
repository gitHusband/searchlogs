#!/usr/bin/env bash
# Replace !/bin/bash, because Mac `brew install bash`, the bash is /usr/local/bin/bash, not /bin/bash

declare -A fileDateCompleteHandlers

# Convert file date to time
# If you have special date format which `date` command can not convert, you can overloaded this function by yourself
if [ $os = "mac" ]; then

    function fileDateToTime()
    {
        # fileDateComplete
        echo "@ fileDateToTime $fileDatetimeFormat"

        ${fileDateCompleteHandlers["$fileDatetimeFormat"]}

        fileTimestamp=`date -j -f "$fileDatetimeFormat" "$fileDatetime" +%s` # Mac

        # echo "FILE: date -j -f "$fileDatetimeFormat" "$fileDatetime" +%s ======> $fileTimestamp"
    }

    # Call this definer when you start to match a file date reg
    function fileDateCompleteDefiner()
    {
        local dateFormat=$1
        # file or line
        local type=$2

        dateFormatBase64=$(echo "$dateFormat" | base64)
        # funcSuffix=${dateFormatBase64%%\=*}
        funcSuffix=${dateFormatBase64//\=/_}
        echo "@ $os - fileDateCompleteDefiner: $dateFormat - $dateFormatBase64 - $funcSuffix"

        # return 0

        case $dateFormat in
            "%Y-%m-%d %H:%M:%S"|"%Y%m%d %H:%M:%S")
                # Do nothing
                function fileDateComplete1()
                {
                    return 0
                }
                fileDateCompleteHandlers["$dateFormat"]=fileDateComplete1
                ;;
            "%Y-%m-%d"|"%Y%m%d")
                function fileDateComplete2()
                {
                    # The end time of the date
                    fileDatetime="$fileDatetime 23:59:59"
                    fileDatetimeFormat="$fileDatetimeFormat %H:%M:%S"
                }
                fileDateCompleteHandlers["$dateFormat"]=fileDateComplete2
                ;;
            *)
                function fileDateComplete4()
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

                    echo "@ Auto datetime complete: $fileDatetimeFormat - $fileDatetime"
                }
                fileDateCompleteHandlers["$dateFormat"]=fileDateComplete4
        esac
    }

else

    function fileDateToTime()
    {
        # fileDateComplete
        echo "@ fileDateToTime $fileDatetimeFormat"

        ${fileDateCompleteHandlers["$fileDatetimeFormat"]}

        fileTimestamp=`date -d "$fileDatetime" +%s` # Linux

        # echo "FILE: date -d "$fileDatetime" +%s ======> $fileTimestamp"
    }

    # Call this definer when you start to match a file date reg
    function fileDateCompleteDefiner()
    {
        local dateFormat=$1
        # file or line
        local type=$2

        dateFormatBase64=$(echo "$dateFormat" | base64)
        # funcSuffix=${dateFormatBase64%%\=*}
        funcSuffix=${dateFormatBase64//\=/_}
        echo "@ $os - fileDateCompleteDefiner: $dateFormat - $dateFormatBase64 - $funcSuffix"

        # return 0

        case $dateFormat in
            "%Y-%m-%d %H:%M:%S")
                # Do nothing
                function fileDateComplete1()
                {
                    echo "@ ==================="
                    return 0
                }
                fileDateCompleteHandlers["$dateFormat"]=fileDateComplete1
                ;;
            "%Y-%m-%d")
                function fileDateComplete2()
                {
                    day=${fileDatetime:0-2}
                    month=${fileDatetime:5:2}
                    year=${fileDatetime:0:4}
                    fileDatetime="$year-$month-$day"

                    # The end time of the date
                    fileDatetime="$fileDatetime 23:59:59"

                    echo "@ $os - $fileDatetime - $fileDatetimeFormat";
                }
                fileDateCompleteHandlers["$dateFormat"]=fileDateComplete2
                ;;
            "%Y%m%d")
                function fileDateComplete3()
                {
                    day=${fileDatetime:0-2}
                    month=${fileDatetime:4:2}
                    year=${fileDatetime:0:4}
                    fileDatetime="$year-$month-$day"

                    # The end time of the date
                    fileDatetime="$fileDatetime 23:59:59"

                    echo "@ $os - $fileDatetime - $fileDatetimeFormat";
                }
                fileDateCompleteHandlers["$dateFormat"]=fileDateComplete3
                ;;
            *)
                function fileDateComplete4()
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

                    echo "@ Auto datetime complete: $fileDatetimeFormat - $fileDatetime"
                }
                fileDateCompleteHandlers["$dateFormat"]=fileDateComplete4
        esac
    }
fi

function fileDateCompleteDefiners()
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
        
        # Define a handler of how to convert date string to timestamp
        
        fileDateCompleteDefiner "$fileDatetimeFormat" "file"

        ((fileDatetimeRegIndex++))
    done

    return 1
}
