#!/bin/bash
###############################################################################
##
##    Section: Abstract Interface:
##      Declate abstract interface for reporting commands like 'ps' & 'images'.
##
###############################################################################
##
###############################################################################
##
##  Purpose:
##    Implement method to obtain specific target packet type required
##    required by specific reporting command.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Inputs:
##    $1 - Variable name to an array whose values contain the label names
##         of the options and agruments appearing on the command line in the
##         order specified by it.  The arguments reflect the names of the
##         components targeted by the dlw command. 
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
##    $3 - dlw command to execute. Maps 1 to 1 onto with Docker command line.
##    $4 - Compute Component prerequisites:
##           'true'    - Yes - According to the "standard" ordering.
##           'false'   - No  - Treat as independent Component.
##           'reverse' - Yes - Reverse the "standard" ordering.
##    $5 - Truncate image GUID in Packets to short, 12 character, GUID:
##           'true' - Truncate to 12.
##           otherwise, use 64 character long version.
##    $6 - Restrict packet generation to only those explicitly specified
##         by the command being processed.  In other words, remove the 
##         implicit parent Components included by the dependency graph.
##         Essentially, permits ordering of the packets by command's
##         dependency graph and then removes any implicit parent Components.
##           'true' - Exclude Component ancestors. 
##           otherwise - Include Component ancestors.
##    SYSYIN - Non specific Component packets in dependency graph order.
## 
##  Outputs:
##    SYSOUT - Augmented packet, appropiate target GUID, in dependency graph order.
##
###############################################################################
function VirtDockerReportingTargetGenerate () {
  ScriptUnwind $LINENO "Please override: $FUNCNAME".
}
###############################################################################
##
##  Purpose:
##    Identifies dlw attribute name of the desired GUID.  Essentially, two
##    types: 'ImageGUID' and a 'ContainerGUID'.
##
##  Inputs:
##    None
##    
##  Outputs:
##    When Successful:
##      SYSOUT - Name of dlw attrubute name.
##    When Failure: 
##      SYSERR - Displays informative error message.
##
###############################################################################
function VirtDockerReportingGUIDattribNameGet () {
  ScriptUnwind $LINENO "Please override: $FUNCNAME".
}
###############################################################################
##
##  Purpose:
##    Identify the reporting colum that must be joined to the target GUID
##    to properly filter and augment the report output generated by one of 
##    the docker reporting commands.
##
##  Inputs:
##    None
## 
##  Outputs:
##    SYSOUT - Augmented packet, appropiate target GUID, in dependency graph order.
##
###############################################################################
function VirtDockerReportingJoinGUIDColmPosGet () {
  ScriptUnwind $LINENO "Please override: $FUNCNAME".
}
###############################################################################
##
##    Section: Common Impementation of virtual functions.
##      Implementation of virtual functions common to reporting commands.
##
###############################################################################
##
###############################################################################
##
##  Purpose:
##    Describes purpose and arguments for reporting commands.
##
###############################################################################
function VirtDockerTargetGenerate (){
  local -r optsArgListNm="$1"
  local -r optsArgMapNm="$2"
  local -r commandNm="$3"
  # if not executing command, then ignore generating targets.
  local -r noExecDocker="`AssociativeMapAssignIndirect "$optsArgMapNm" '--dlwno-exec'`"
  if $noExecDocker; then return 0; fi
  # determine the size of the GUID desired in the report.
  local -r dockerNoTrunc="`AssociativeMapAssignIndirect "$optsArgMapNm" '--no-trunc'`"
  local truncGUID='true'
  if [ -z "$dockerNoTrunc" ]; then
    if AssociativeMapKeyExist "$optsArgMapNm" '--no-trunc'; then
      truncGUID='false'
    fi
  elif [ "$dockerNoTrunc" == 'true' ]; then
    $truncGUID='false'
  fi
  local -r computePrereqs="`AssociativeMapAssignIndirect "$optsArgMapNm" '--dlwparent'`"
  VirtDockerReportingTargetGenerate "$optsArgListNm" "$optsArgMapNm" "$commandNm" "$computePrereqs" "$truncGUID" 'false'
  return 0
}
source "VirtDockerCmmdSingle.sh";
###############################################################################
function VirtDockerCmmdAssembleSingle () {
  echo "docker $2 $3"
}
###############################################################################
function VirtDockerCmmdExecutePacketForward () {
  echo 'false'
}
###############################################################################
##
##  Purpose:
##    Capture Docker reporting command output and apply filtering, similar
##    to a relational join operator, to only report on defined targets.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Inputs:
##    $1 - Variable name to an array whose values contain the label names
##         of the options and agruments appearing on the command line in the
##         order specified by it.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
##    $3 - dlw command to execute. Maps 1 to 1 onto with Docker command line.
##    SYSIN - Output from the Execute command.
##    VirtDockerReportingJoinGUIDColmPosGet - Virtual callback function 
##      providing the Image GUID/Name column position as displayed 
##      by the docker reporting command. 
## 
##  Inputs:
##    SYSOUT - A filtered docker report displaying only the specified Components.
##             The report may also be augmented with additional column(s)
## 
###############################################################################
function VirtDockerCmmdProcessOutput () {
  local -r optsArgListNm="$1"
  local -r optsArgMapNm="$2"
  local -r commandNm="$3"
  local -r joinImageColmPos="`VirtDockerReportingJoinGUIDColmPosGet`"
  local outputHeadingNot
  AssociativeMapAssignIndirect "$optsArgMapNm" '--dlwno-hdr' 'outputHeadingNot'
  local -A colmIncludeMap
  if ! ColmIncludeDetermine "`AssociativeMapAssignIndirect "$optsArgMapNm" '--dlwcol'`" 'colmIncludeMap'; then
    ScriptUnwind $LINENO "Problem with --dlwcol argument."
  fi
  if [ -n "${colmIncludeMap['none']}" ]; then
    # specifying 'none' as an attribute name omits all extended columns.
    unset colmIncludeMap
    local -A colmIncludeMap
  fi
  local -r GUIDattribName=`VirtDockerReportingGUIDattribNameGet`
  local -A GUIDvalueFilterMap
  local -A GUIDvalueMap
  local headingProcessed='false'
  local packet
  while read packet; do
    PipeScriptNotifyAbort "$packet"
    if PacketPreambleMatch "$packet"; then
      PacketConvertToAssociativeMap "$packet" 'GUIDvalueMap'
      local GUIDvalue="${GUIDvalueMap["$GUIDattribName"]}"
      if [ -z "$GUIDvalue" ]; then echo "$packet"; fi # packet detected but not of desired type - forward it.
      # determine the columns to display for this entry and compute the complete
      # set of extended columns supported  by the report after visiting all packets.
      unset colmBagArray
      local -a colmBagArray
      if ! ColumnAttributesDiscern 'colmIncludeMap' 'GUIDvalueMap' 'colmBagArray'; then 
        ScriptUnwind $LINENO "Problem while discerning report column attributes."
      fi
      # associate serialized array of attribute values with join GUID
      GUIDvalueFilterMap["$GUIDvalue"]="`typeset -p colmBagArray`"
      # continue processing packets until first non-packet
      continue
    fi
    if ! $headingProcessed; then
      # first non-packet is output from docker report command.  Most likely a heading
      # if not omitted by, for example, the -q option.
      headingProcessed='true'
      local dockerHdrInd='false'
      if DockerHeadingSpecified "$packet"; then dockerHdrInd='true'; fi 
      if ! $outputHeadingNot; then
        #  user wants dlw column headings, but are there Docker headings
        if $dockerHdrInd; then
          if [ "${#colmIncludeMap[@]}" -gt 0 ]; then
            # packet contained Docker report heading :: prefix with extended attributes column headings.
            echo "`ExtendedHeadingsGenerate 'colmIncludeMap'` $packet"
          else
            # no extended columns in this report :: output Docker heading
            echo "$packet"
          fi
          continue
        elif [ "${#colmIncludeMap[@]}" -gt 0 ]; then
          # dlw heading requested, but most likely Docker report heading omitted.
          # packet probably contains detail row of report so let it be considered
          # below, however, generate dlw column headings.
          echo "`ExtendedHeadingsGenerate 'colmIncludeMap'`"
        fi
         # Docker heading detected but headings are suppressed 
      fi
    fi
    # not a heading nor a dlw packet, most likely a reporting detail row.
    # see if GUID matches join column in output which is most likely a GUID.
    local possibleGUID="`echo "$packet" | awk  "{ print $joinImageColmPos }"`"
    if [ -z "$possibleGUID" ]; then
      # see if GUID matches first column in output, use of -q docker option
      possibleGUID="`echo "$packet" | awk  '{ print $1 }'`"
      # if empty packet, skip without forwarding packet
      if [ -z "$possibleGUID" ]; then continue; fi
    fi
    # possible GUID has a value :: following dereferencing works
    local possibleComp="${GUIDvalueFilterMap["$possibleGUID"]}"
    if [ -n "$possibleComp" ]; then
      if [ "${#colmIncludeMap[@]}" -gt 0 ]; then
        # extended columns are requested for the report
        local colmExendedBuf
        ExtendedColumnsGenerate 'colmIncludeMap' "$possibleComp" 'colmExendedBuf'
        echo "${colmExendedBuf} ${packet}"
      else
        echo "${packet}"
      fi
    fi
    # Packets that don't match anything expected above are ignored/dropped.
  done
  return 0
}
FunctionOverrideIncludeGet
