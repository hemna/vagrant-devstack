# Common menu code for each of the scripts in this dir.

# for whiptail sizing
lines=$(tput lines)
cols=$(tput cols)
menu_h=$((lines-3))
menu_w=$((cols-5))
menu_l=$((lines-11))


# Display a menu:
#   Usage: title [choice...]
#
menu() {
    title=$1
    shift

    typeset -a args
    while [[ $# -gt 0 ]] ; do
        args+=($1)  # Programmatic tag to return when this item chosen
        args+=($1)  # Descriptive text to display
        shift
    done

   # run whiptail and swap stderr and stdout
   (whiptail --noitem --menu "$title" $menu_h $menu_w $menu_l ${args[@]} 3>&1 1>&2 2>&3)
}
