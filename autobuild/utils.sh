# rsync should take account of SSH_OPTS
RSYNC_RSH="ssh $SSH_OPTS"
export RSYNC_RSH

function die () {
  echo "$@" 2>&1
  exit 1
}

function absolutify_scriptdir () {
    # SCRIPTDIR should be absolute
    case $SCRIPTDIR in
    /*)
        ;;
    *)
        SCRIPTDIR="$PWD/$SCRIPTDIR"
        ;;
    esac
}

function check_vars () {
    # Check mandatory settings
    for v in $mandatory_vars ; do
        [[ -n "${!v}" ]] || die "$v not set"
    done

    echo "Settings:"
    for v in $mandatory_vars $optional_vars ; do
        echo "${v}=${!v}"
    done
}

