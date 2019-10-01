#!/bin/bash -
#title           :environment
#description     :Script to check the Documentation of a KS module
#author          :Alejandro Villegas Lopez (avillegas@keedio.com).
#===============================================================================


TRUE=1
FALSE=0


#=============================
# MSG Functions
#===============================================================================

# Error Message
function _err_msg () {
  echo -e "\033[37m[\033[31m ERR \033[37m]\033[0m $@"
}

# Warning Message
function _war_msg () {
  echo -e "\033[37m[\033[33m WAR \033[37m]\033[0m $@"
}

# OK Message
function _ok_msg () {
  echo -e "\033[37m[\033[32m OK  \033[37m]\033[0m $@"
}

# Info Message
function _info_msg () {
  echo -e "\033[37m[\033[34m INF \033[37m]\033[0m $@"
}


#=============================
# AUX Functions
#===============================================================================
function check_if_file_exists () {
  [[ -f $1 ]] && { return $TRUE; } || { _err_msg "$1 file not found in $(dirname $(pwd))"; return $FALSE; }
}




#=============================
# License File Checking Module
#===============================================================================

function check_license_file_exists () {
  check_if_file_exists "LICENSE"
}

function check_license_apache () {
  local license_name=$(head -1 LICENSE | sed -e 's/^[[:space:]]*//g')
  local license_version=$(sed '2q;d' LICENSE | sed -e 's/^[[:space:]]*//g' | awk '{ print $2 }' | sed 's/.$//')

  [[ "$license_name" == "Apache License" ]] && { _ok_msg "License is Apache Type"; return $TRUE; } || { _err_msg "License is not Apache"; return $FALSE; }
  [[ $license_version == "2.0" ]] && { _ok_msg "Apache License is at version 2.0"; return $TRUE; } || { _err_msg "Apache License is at version 2.0"; return $FALSE; }
}

function check_license_signed () {
  local fill=$(egrep "Copyright [0-9]{4} Keedio" LICENSE)
  local retval_grep=$?
  local year=$(echo "$fill" | awk '{ print $2 }')

  [[ $retval_grep -eq 0 ]] && { _ok_msg "License signed"; } || { _err_msg "License is not signed"; return $FALSE; }
  [[ "$year" != $(date +%Y) ]] && { _err_msg "Year of the License Copyright is outdated"; return $FALSE; } || { return $TRUE; }
}

function check_license () {
  _info_msg "Checking LICENSE file"
  check_license_file_exists
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_license_apache
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_license_signed
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  _ok_msg "LICENSE file is correct"
  return $TRUE
}




#=============================
# Notice File Checking Module
#===============================================================================

function check_notice_file_exists () {
  check_if_file_exists "NOTICE.md"
}

function check_notice_copyright_year () {
  local current_year=$(date +%Y)
  local notice_year=$(grep Copyright NOTICE.md | awk '{ print $2 }')
  [[ $current_year == $notice_year ]] && { _ok_msg "Copyright Year is updated"; return $TRUE; } || { _err_msg "Notice file Copyright Year is outdated"; return $FALSE; }

}

function check_notice () {
  _info_msg "Checking NOTICE.md file"
  check_notice_file_exists
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_notice_copyright_year
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  _ok_msg "NOTICE.md file is correct"
  return $TRUE
}





#=============================
# Git Checking Module
#===============================================================================

function check_git_is_a_git_repo () {
  [[ -d .git ]] && { _ok_msg "Is a Git Repository"; return $TRUE; } || { _err_msg "Is not a Git Repository"; return $FALSE; }
}

function check_git () {
  _info_msg "Checking Git"
  check_git_is_a_git_repo
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  _ok_msg "Git repo is correct"
  return $TRUE
}





#=============================
# Version File Checking Module
#===============================================================================

function check_version_file_exists () {
  check_if_file_exists "VERSION"
}

function check_version_format () {
  egrep -q "^[0-9]+\.[0-9]+(\.[0-9]+)?(-beta)?(-LTS)?$" VERSION
  [[ $? -eq 0 ]] && { return $TRUE; } || { _err_msg "Version format invalid"; return $FALSE; } 
}

function check_version_git_tags () {
  grep -q $(cat VERSION) <<< "$(git tag)"
  [[ $? -eq 0 ]] && { return $TRUE; } || { _war_msg "Current version ( $(cat VERSION) ) are not in the git remote server"; return $FALSE; } 
}

function check_version () {
  _info_msg "Checking Version file"
  check_version_file_exists
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_version_format
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_version_git_tags
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  _ok_msg "Version file is correct"
  return $TRUE
}




#=============================
# Changelog File Checking Module
#===============================================================================



# ^[0-9]+\.[0-9]+(\.[0-9]+)?(-beta)?(-LTS)? \((([0-2][0-9])|(3[0-1]))\/(([1-9])|(0[1-9])|(1[0-2]))\/([0-9]{4})\)$
function check_changelog_file_exists () {
  check_if_file_exists "CHANGELOG.md"
}

function check_changelog_if_version_is_documented () {
  local chl_versions="$(egrep '^[0-9]+\.[0-9]+(\.[0-9]+)?(-beta)?(-LTS)? \((([0-2][0-9])|(3[0-1]))\/(([1-9])|(0[1-9])|(1[0-2]))\/([0-9]{4})\)$' CHANGELOG.md | awk 'FS=" " { print $1 }' | sort)"
  local git_versions="$(git tag | sort)"
  local retval=$TRUE

  # Versions documented and not uploaded
  vdnu="$(comm -2 -3 <(echo "${chl_versions[@]}") <(echo "${git_versions[@]}"))"

  # Versions not documented and uploaded
  vndu="$(comm -1 -3 <(echo "${chl_versions[@]}") <(echo "${git_versions[@]}"))"

  # Check if there are versions documented but not uploaded
  for v in ${vdnu[@]}; do
    _err_msg "Version $v is documented in changelog but is not present on Git Repository"
    retval=$FALSE
  done

  # Check if there are versions uploaded but not documented
  for v in ${vndu[@]}; do
    _err_msg "Version $v is not documented in changelog but is present on Git Repository"
    retval=$FALSE
  done
  
  return $retval
}

function check_changelog () {
  _info_msg "Checking Changelog file"
  check_changelog_file_exists
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  check_changelog_if_version_is_documented
  [[ $? -ne $TRUE ]] && { return $FALSE; }

  _ok_msg "Changelog file is correct"
  return $TRUE
}





#=============================
# Main Functions
#===============================================================================
function help_msg () {
  printf "Repo Checker Help message:
  Version: 0.1-beta
  
  ./autocheck.sh -p <KS_MODULE_PATH>          Check the repo in the path specified
  ./autocheck.sh -h                           Display this message
\n"
}


function get_cl_args () {
  while getopts "p:h" arg; do
    case $arg in
      p)
        CHECK_PATHS="$OPTARG"
        ;;
      h)
        help_msg
        ;;
      *)
        help_msg
        ;;
    esac
  done

}


function run () {
  cd $CHECK_PATHS
  local total_checks=5
  local retval=0

  # Check if is a Git repository
  check_git
  retval=$(($retval + $?))


  # Check version
  check_version
  retval=$(($retval + $?))


  # Check Notice
  check_notice
  retval=$(($retval + $?))


  # Check Changelog
  check_changelog
  retval=$(($retval + $?))


  # Check License
  check_license
  retval=$(($retval + $?))

  cd - &>/dev/null


  [[ $retval -eq $total_checks ]] && { _ok_msg "Finished without errors! :D"; } || { _err_msg "Docs not completed. Total errors: $(($total_checks - $retval))"; }
}

function main () {
  [[ $# -eq 0 ]] && { help_msg; return; }
  get_cl_args $@
  run
}


main $@


