#!/bin/echo This file must be sourced by a bash shell

warn(){
  if [ "a$1" = "a-n" ]; then
    shift
    printf "$@" >&2
  else
    if [ "a$1" = "a--" ]; then
      shift
    fi
    local templ="$1"
    shift
    printf "$templ\n" "$@" >&2
  fi
}

fail(){
  warn "$@"
  exit 1
}

has(){
  which "$@" >/dev/null 2>&1
}

contains(){
  grep "$@" >/dev/null 2>&1
}

econtains(){
  egrep "$@" >/dev/null 2>&1
}

fcontains(){
  fgrep "$@" >/dev/null 2>&1
}

abspath(){
  if [[ -n "$1" ]]; then
  (
    if [[ -n "$2" ]]; then
      cd "$2"
    fi
    cd "$(dirname "$1")"
    echo "$PWD/$(basename "$1")"
  )
  fi
}

shquote(){
	local HEAD TAIL="$*"
	printf "'"

	while [ -n "$TAIL" ]; do
		HEAD="${TAIL%%\'*}"

		if [ "$HEAD" = "$TAIL" ]; then
			printf "%s" "$TAIL"
			break
		fi

		printf "%s'\"'\"'" "$HEAD"

		TAIL="${TAIL#*\'}"
	done

	printf "'"
}

not(){
  if [[ $1 == true ]]; then
    echo false
  elif [[ $1 == false ]]; then
    echo true
  fi
}

redo-cat(){
  redo-ifchange "$@"
  cat "$@"
}

redo-catx(){
  ( set +e
    redo-ifchange "$@"
    local v
    for v in "$@"; do
      if ! [ -e "$v" ]; then
        redo-ifcreate "$v"
      fi
    done
    cat "$@" 2>/dev/null
  )
  return 0
}

redo-source(){
  redo-ifchange "$@"
  while [ $# -gt 0 ]; do
		. "$1"
		shift
	done
}

redo-source-cat(){
  redo-ifchange "$@"
  while [ $# -gt 0 ]; do
		. "$1"
		cat "$1"
		shift
	done
}

# do-record var default-val val
do-record(){
  local quiet=false
  while true; do
    case "$1" in
      -q) quiet=true; shift ;;
      *)  break ;;
    esac
  done

  local val="${3:-"$2"}"
  eval $1='$val'

  if ! $quiet; then
    printf "%s\n" "$1=$(shquote "$val")"
  fi
}

# do-recordf var default-val valfile
do-recordf(){
  local quiet=
  while true; do
    case "$1" in
      -q) quiet=-q; shift ;;
      *)  break ;;
    esac
  done

  do-record $quiet "$1" "$2" "$(redo-catx "$3")"
}

# do-recordc var default-val
do-recordc(){
  local quiet=
  while true; do
    case "$1" in
      -q) quiet=-q; shift ;;
      *)  break ;;
    esac
  done

  do-recordf $quiet "$1" "$2" "${DOPS_MYCONF:-"$DOPS_CONF/$(basename "$PWD")"}/$1"
}

do-getconf(){
  do-recordc -q "$@"
}

dopsh-init(){
  DOPSH_CALL_DIR="$PWD"
  if [ -z "$DOPSH_ARG0" ]; then
    DOPSH_ARG0="$1"
    shift
  fi
  if [ -z "$DOPSH_ARGS" ]; then
    DOPSH_ARGS=("$@")
  fi
  cd "$(dirname "$DOPSH_ARG0")"
}

# Parse --op=var specification
#   specification -> isop (set opname and opvar)
#   template arg  -> isop (set opname and opval, opval empty if on next arg)
_dopsh-opt-isopstr(){
  local template= op op2 op3
  if [[ $# -ge 2 ]]; then
    template=" $1 "
    shift
  fi
  op="$1"
  op2="${op#-}"
  op2="${op2#-}"
  op3="${op2%%=*}"
  local template2="${template// -$op3=/}"
  template2="${template2// --$op3=/}"
  if [[ -n "$template" ]] && [[ "$template2" != "$template" ]]; then
    opname="$op3"
    if [[ "a$op2" != "a$op3" ]]; then
      opval="${op2#*=}"
    else
      opval=""
    fi
    return 0
  elif [[ -z "$template" ]] && [[ "a$op" != "a$op3" ]]; then
    opname="$op3"
    opvar="${op2#*=}"
    return 0
  else
    return 1
  fi
}

# Parse --[no-]op specification
#   specification -> isop (set opname)
#   template arg  -> isop (set opname and opval, opval empty on format error)
_dopsh-opt-isopbool(){
  local template= op op2 op3 op4
  if [[ $# -ge 2 ]]; then
    template=" $1 "
    shift
  fi
  op="$1"
  op2="${op#-}"
  op2="${op2#-}"
  op3="${op2%%=*}"
  op4="${op3#no-}"
  local template2="${template// -$op4 /}"
  template2="${template2// --$op4 /}"
  if [[ -n "$template" ]] && [[ "$template2" != "$template" ]]; then
    if [[ "a$op2" != "a$op3" ]]; then
      opname="$op3"
      opval="${op2%*=}"
      if [[ ( true = "$opval" ) || ( 1 = "$opval" ) ]]; then
        opval=true
      elif [[ ( false = "$opval" ) || ( 0 = "$opval" ) ]]; then
        opval=false
      else
        opval=
      fi
    else
      opname="$op4"
      if [[ "a$op3" = "a$op4" ]]; then
        opval=true
      else
        opval=false
      fi
    fi
    return 0
  elif [[ -z "$template" ]] && [[ "a$op" != "a$op2" ]]; then
    opname="$op3"
    return 0
  else
    return 1
  fi
}

# Parse --[no-]op specification
#   specification -> isop (set opname and helpstatus)
#   template arg  -> isop (set opname and helpstatus)
_dopsh-opt-isophelp(){
  local template= op op2 op3 op4
  if [[ $# -ge 2 ]]; then
    template=" $1 "
    shift
  fi
  op="$1"
  op2="${op#-}"
  op2="${op2#-}"
  op3="${op#H:}"
  op4="${op#h:}"
  if [[ -n "$template" ]] && [[ "${template// h:$op2 /}" != "$template" ]]; then
    opname="$op2"
    helpstatus=0
    return 0
  elif [[ -n "$template" ]] && [[ "${template// H:$op2 /}" != "$template" ]]; then
    opname="$op2"
    helpstatus=1
    return 0
  elif [[ -z "$template" ]] && [[ "a$op" != "a$op3" ]]; then
    opname="$op3"
    helpstatus=1
    return 0
  elif [[ -z "$template" ]] && [[ "a$op" != "a$op4" ]]; then
    opname="$op4"
    helpstatus=0
    return 0
  else
    return 1
  fi
}

# Parse ARG... specification
#   specification -> islist (set opname)
_dopsh-opt-islist(){
  local op op2 op3
  op="$1"
  op2="${op%+}"
  op3="${op%...}"
  if [[ "a$op" != "a$op2" ]]; then
    opname="$op2"
    return 0
  elif [[ "a$op" != "a$op3" ]]; then
    opname="$op3"
    return 0
  else
    return 1
  fi
}

# Parse [ARG...] specification
#   specification -> islist (set opname)
_dopsh-opt-isoptlist(){
  local op op2 op3 op4
  op="$1"
  op2="${op%\*}"
  op3="${op%...\]}"
  op4="${op3#\[}"
  if [[ "a$op" != "a$op2" ]]; then
    opname="$op2"
    return 0
  elif [[ ( "a$op" != "a$op3" ) && ( "a$op3" != "a$op4" ) ]]; then
    opname="$op4"
    return 0
  else
    return 1
  fi
}

# Parse [ARG] specification
#   specification -> isoptarg (set opname)
_dopsh-opt-isoptarg(){
  local op op2 op3 op4
  op="$1"
  op2="${op%\?}"
  op3="${op%\]}"
  op4="${op3#\[}"
  if [[ "a$op" != "a$op2" ]]; then
    opname="$op2"
    return 0
  elif [[ ( "a$op" != "a$op3" ) && ( "a$op3" != "a$op4" ) ]]; then
    opname="$op4"
    return 0
  else
    return 1
  fi
}

dopsh-usage(){
  local op opname opvar opval helpstatus
  local help=false
  local preargs=("$DOPSH_ARG0" "${DOPSH_PREARGS[@]}")
  echo -n "${preargs[@]}"
  for op in $template; do
    if _dopsh-opt-isopstr "$op"; then
      opvar=${opvar:-?}
      echo -n " --$opname=${opvar^^}"
    elif _dopsh-opt-isopbool "$op"; then
      echo -n " --[no-]$opname"
    elif _dopsh-opt-isophelp "$op"; then
      help=true
    elif _dopsh-opt-islist "$op"; then
      echo -n " ${opname^^}..."
    elif _dopsh-opt-isoptlist "$op"; then
      echo -n " [${opname^^}...]"
    elif _dopsh-opt-isoptarg "$op"; then
      echo -n " [${opname^^}]"
    else
      echo -n " ${op^^}"
    fi
  done
  echo
  if $help; then
    echo -n "${preargs[@]}"
    for op in $template; do
      if _dopsh-opt-isophelp "$op"; then
        echo -n " --${opname}"
      fi
    done
    echo " (show this help)"
  fi
}

dopsh-parseopt(){
  local op opname opvar opval helpstatus template=" $1 "
  shift
  opts=()
  for op in $template; do
    if _dopsh-opt-isopstr "$op"; then
      unset op_${opname//-/_}
      eval "op_${opname//-/_}s=()"
    elif _dopsh-opt-isopbool "$op"; then
      unset op_${opname//-/_}
      eval "op_${opname//-/_}s=()"
    elif _dopsh-opt-isophelp "$op"; then
      unset op_${opname//-/_}
      eval "op_${opname//-/_}s=()"
    elif _dopsh-opt-isoptlist "$op"; then
      eval "op_${opname//-/_}s=()"
    elif _dopsh-opt-isoptarg "$op"; then
      eval "op_${opname//-/_}=()"
    elif _dopsh-opt-islist "$op"; then
      eval "op_${opname//-/_}s=()"
    else
      unset op_${op//-/_}
    fi
  done
  while [ $# -gt 0 ]; do
    case "$1" in
      --)
        shift
        opts=("${opts[@]}" "$@")
        break
        ;;
      *)
        opname=
        if _dopsh-opt-isopstr "$template" "$1"; then
          if [[ -z "$opval" ]]; then
            opval="$2"
            shift
          fi
        elif _dopsh-opt-isopbool "$template" "$1"; then
          if [[ -z "$opval" ]]; then
            echo "Expected true or false for --$opname" >&2
            dopsh-usage "$template" >&2
            return 1
          fi
        elif _dopsh-opt-isophelp "$template" "$1"; then
          dopsh-usage "$template" >&2
          return $helpstatus
        else
          opts=("${opts[@]}" "$1")
        fi
        if [[ -n "$opname" ]]; then
          #eval "declare -a op_${opname//-/_}s" # declare -a makes it local
          eval "op_${opname//-/_}s+=(\"\$opval\")"
          eval "op_${opname//-/_}=\"\$opval\""
        fi
        shift
        ;;
    esac
  done
  for op in $template; do
    if _dopsh-opt-isopstr "$op"; then
      :
    elif _dopsh-opt-isopbool "$op"; then
      :
    elif _dopsh-opt-isophelp "$op"; then
      :
    elif [[ "a${opts[0]#-}" != "a${opts[0]}" ]]; then
      echo "Unknown option ${opts[0]}" >&2
      dopsh-usage "$template" >&2
      return 1
    elif _dopsh-opt-isoptlist "$op"; then
      eval "op_${opname//-/_}s=(\"\${opts[@]}\")"
      DOPSH_PREARGS+=("${opts[@]}")
      opts=()
    elif _dopsh-opt-isoptarg "$op"; then
      eval "op_${opname//-/_}=\"\${opts[0]}\""
      DOPSH_PREARGS+=("${opts[0]}")
      opts=("${opts[@]:1}")
    elif [ "${#opts[@]}" -eq 0 ]; then
      if _dopsh-opt-islist "$op"; then
        echo "Missing argument ${opname^^}..." >&2
      else
        echo "Missing argument ${op^^}" >&2
      fi
      dopsh-usage "$template" >&2
      return 1
    elif _dopsh-opt-islist "$op"; then
      eval "op_${opname//-/_}s=(\"\${opts[@]}\")"
      DOPSH_PREARGS+=("${opts[@]}")
      opts=()
    else
      eval "op_${op//-/_}=(\"\${opts[0]}\")"
      DOPSH_PREARGS+=("${opts[0]}")
      opts=("${opts[@]:1}")
    fi
  done
}

# usage: [-file] name defaultval [alias...]
dopsh-opt(){
  local aliasvar
  local isfile=false
  if [[ "a$1" == "a-file" ]]; then
    isfile=true
    shift
  fi
  local var="$1"
  local val="$2"
  shift 2
  for aliasvar in "$@"; do
    eval ": \${op_${var}:=\"\$op_$aliasvar\"}"
  done
  eval ": \${op_${var}:=\"\$val\"}"
  if $isfile; then
    eval "op_${var}=\"\$(abspath \"\$op_$var\" \"\$DOPSH_CALL_DIR\")\""
  fi
}

redo-always-stamp(){
  redo-always
  local in=${1:-$(abspath "${DOPSH_ARGS[2]}" "$DOPSH_CALL_DIR")}
  if [ "a$in" = "a-" ]; then
    redo-stamp
  else
    redo-stamp <"$in" 
  fi
}

