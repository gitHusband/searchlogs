#!/usr/bin/env bash
# Replace !/bin/bash, because Mac `brew install bash`, the bash is /usr/local/bin/bash, not /bin/bash

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