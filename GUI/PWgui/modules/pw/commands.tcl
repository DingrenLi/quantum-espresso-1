
# ------------------------------------------------------------------------
#  ::pwscf::pwSelectPseudoDir --
# ------------------------------------------------------------------------

proc ::pwscf::pwSelectPseudoDir {moduleObj} {
    variable pwscf
    global env

    set _dir [$moduleObj varvalue pseudo_dir]
    if { [file isdirectory $_dir] } {
	set dir $_dir
    } elseif { [info exists pwscf($moduleObj,LASTDIR,pseudo_dir)] } {
	set dir $pwscf($moduleObj,LASTDIR,pseudo_dir)
    } else {
	set dir [file join $env(HOME) pw pseudo]
	if { ! [file exists $dir] } {
	    set dir pwscf(PWD)
	}
    }

    set dir [tk_chooseDirectory -initialdir $dir \
		 -title "Chose directory" -mustexist 0]
    if { $dir == "" } {
	return
    }
    set pwscf($moduleObj,LASTDIR,pseudo_dir) $dir    
    
    # add a trailing slash "/"
    set dir [string trimright [file join $dir _] _]
    # add a quotes
    set dir '$dir'
    $moduleObj varset pseudo_dir -value $dir

}


# ------------------------------------------------------------------------
#  ::pwscf::pwSelectPseudopotential --
# ------------------------------------------------------------------------

proc ::pwscf::pwSelectPseudopotential {moduleObj variable ir ic} {
    variable pwscf
    global env
        
    set _dir [string trim [$moduleObj varvalue pseudo_dir] "'"]
    if { [file isdirectory $_dir] } {
	set dir $_dir
    } elseif { [info exists pwscf($moduleObj,LASTDIR,pseudopotential)] } {
	set dir $pwscf($moduleObj,LASTDIR,pseudopotential)
    } else {
	set dir [file join $env(HOME) pw pseudo]
	if { ! [file isdirectory $dir] } {
	    set dir $pwscf(PWD)
	}    
    }
        
    set file [tk_getOpenFile \
		  -initialdir $dir \
		  -title      "Select a Pseudopotential File"]    
    if { $file == "" } {
	return
    }
    set pwscf($moduleObj,LASTDIR,pseudopotential) [file dirname $file]
    
    $moduleObj varset ${variable}($ir,$ic) -value [file tail $file]
}


# ------------------------------------------------------------------------
#  ::pwscf::pwLoadAtomCoord --
# 
# This function loads atomic coordinates from file. It supposes the
# PWSCF syntax, i.e., searches for ATOMIC_POSTIONS keyword. This means
# that atomic coordinates can be extracted from PWSCF's input file.
# ------------------------------------------------------------------------
proc ::pwscf::pwLoadAtomCoor {moduleObj} {
    set file [pwLoadAtomCoor:_init $moduleObj]
    pwLoadAtomCoor:_read $moduleObj $file atomic_coordinates
}
proc ::pwscf::pwLoadAtomCoor2 {moduleObj} {
    set file [pwLoadAtomCoor:_init $moduleObj]
    pwLoadAtomCoor:_read $moduleObj $file atomic_coordinates2
}
proc ::pwscf::pwLoadAtomCoor:_init {moduleObj} {
    variable pwscf

    if { [info exists pwscf($moduleObj,LASTDIR,atomic_coor)] } {
	set dir $pwscf($moduleObj,LASTDIR,atomic_coor)
    } else {
	set dir pwscf(PWD)	
    }
    
    # query the filename
    
    set file [tk_getOpenFile \
		  -initialdir $dir \
		  -title "Load Atomic Coordinates"]
    if { $file == "" } {
	uplevel 1 return
    }
    set pwscf($moduleObj,LASTDIR,atomic_coor) [file dirname $file]
    return $file
}
proc ::pwscf::pwLoadAtomCoor:_read {moduleObj file coorVar} {
    variable pwscf

    # read the file

    set channel [open $file r]
    
    set _readCoor 0
    set IA(0)     0
    set IA(1)     0
    set IA(2)     0
    set ntyp_list {}
    set _UNIT     ""    
    set image 0
    set first_image 0
    set last_image 0

    while {1} {
	set res [gets $channel _line]
	if { $res == -1 && $_line == "" } {
	    # end of file occurred
	    break
	}    

	set _len [llength $_line]

	# skip empty lines
	if { $_len == 0 } {
	    continue
	}
	
	if { [string match "ATOMIC_POSITIONS*" $_line] } {
	    set _line [readFilter::purifyCardLine $_line]
	    set _UNIT [lindex $_line 1]
	    set _readCoor 1
	    continue
	}	
	if { $_readCoor } {
	    if { $_len == 4 || $_len == 7 } {
		# read coordinates
		incr IA($image)
		set ia $IA($image)
		set len($ia,$image) $_len
		for {set i 1} {$i <= $_len} {incr i} {
		    set Atoms($ia,$i,$image) [lindex $_line [expr $i - 1]]
		}
		if { [lsearch -exact $ntyp_list $Atoms($ia,1,$image)] == -1 } {
		    lappend ntyp_list $Atoms($ia,1,$image)
		}
	    } elseif { $_len == 1 } {
		# might be first_image or last_image string (NEB)
		if { [string match *first_image* $_line] && $image == 0 } {
		    incr image
		    set first_image 1
		} elseif { [string match *last_image* $_line] && $image == 1 } {
		    incr image
		    set last_image  1
		} else {
		    # no, it is not first_image/last_image string 
		    break
		}
	    } else {
		# record does not match; probably end-of-ATOMIC_POSITIONS
		break
	    }
	}
    }
    #/reading done

    # assign the "atomic-position" variables
    
    set ia $IA(0)
    if { $image >= 1 } {  if { $IA(1) > $ia } { set ia $IA(1) }  }
    if { $image == 2 } {  if { $IA(2) > $ia } { set ia $IA(2) }  }	
    $moduleObj varset nat -value $ia
    #$moduleObj varset ntyp -value $NTYP

    if { $_UNIT != "" } {
	$moduleObj varset atmpos_unit -value [$moduleObj valueToTextvalue atmpos_unit $_UNIT]
    }

    # load atomic-labels from ntyp_list if the "atomic_species" is not yet defined
    
    set ntyp [llength $ntyp_list]
    $moduleObj varset ntyp -value $ntyp
    for {set i 1} {$i <= $ntyp} {incr i} {
	set empty($i) 1
    }
    foreach type $ntyp_list {
	set new_type 1
	for {set i 1} {$i <= $ntyp} {incr i} {
	    if { $type == [$moduleObj varvalue atomic_species($i,1)] } {
		set new_type  0
		set empty($i) 0
	    }
	}
	if { $new_type } {
	    for {set i 1} {$i <= $ntyp} {incr i} {
		if { $empty($i) } {
		    $moduleObj varset atomic_species($i,1) -value $type
		    set empty($i) 0
		    break
		}
	    }
	}
    }

    # load the "atomic_coordinates" or "atomic_coordinates2" table 

    if { $coorVar == "atomic_coordinates" } {
	if { ! $first_image } {
	    set ith 0
	} elseif { $first_image && $last_image } {
	    set ith {1 2}
	} elseif { $first_image } {
	    set ith 1
	}
    } elseif { $coorVar == "atomic_coordinates2" } {
	if { ! $last_image } {
	    set ith 0
	} elseif { $first_image && $last_image } {
	    set ith {1 2}	
	} elseif { $last_image } {
	    set ith 2
	}
    }
    
    puts stderr "ITH: $ith"
    foreach ii $ith {
	for {set ia 1} {$ia <= $IA($ii)} {incr ia} {
	    if { ! [info exists len($ia,$ii)] } { 
		break 
	    }
	    for {set i 1} {$i <= $len($ia,$ii)} {incr i} {
		if { ! [info exists Atoms($ia,$i,$ii)] } { 
		    break 
		}
		if { $ii == 0 } {
		    $moduleObj varset "${coorVar}($ia,$i)" -value $Atoms($ia,$i,$ii)
		} elseif { $ii == 1 } {
		    $moduleObj varset "atomic_coordinates($ia,$i)"  -value $Atoms($ia,$i,$ii)
		} elseif { $ii == 2 } {
		    $moduleObj varset "atomic_coordinates2($ia,$i)" -value $Atoms($ia,$i,$ii)
		}
	    }
	}
    }
}


# ------------------------------------------------------------------------
#  ::pwscf::pwLoadKPoints --
# ------------------------------------------------------------------------

proc ::pwscf::pwLoadKPoints {moduleObj} {
    variable pwscf

    if { [info exists pwscf($moduleObj,LASTDIR,k_points)] } {
	set dir $pwscf($moduleObj,LASTDIR,k_points)
    } else {
	set dir pwscf(PWD)	
    }

    #
    # query filename
    #
    set file [tk_getOpenFile -initialdir [pwd] -title "Load K-Points"]
    if { $file == "" } {
	return
    }
    set pwscf($moduleObj,LASTDIR,k_points) [file dirname $file]

    #
    # read the file
    #
    set channel [open $file r]
    # find the K_POINTS card
    while {1} {
	set _line [_getsNonEmptyLine $channel]
	
	if { [string match "K_POINTS*" $_line] } {
	    set _line [readFilter::purifyCardLine $_line]
	    set _UNIT [lindex $_line 1]
	    # assing the kpoint_type variable
	    $moduleObj varset kpoint_type -value [$moduleObj valueToTextvalue kpoint_type $_UNIT]
	    break
	}
    }	    
    # read NKS
    set NKS [_getsNonEmptyLine $channel]
    if { [string is integer $NKS] } {
	$moduleObj varset nks -value $NKS
    } else {
	# TODO: raise an error
	return
    }
    # read K-POINTS
    for {set ia 1} {$ia <= $NKS} {incr ia} {
	set _line [_getsNonEmptyLine $channel]
	if { [llength $_line] != 4 } {
	    # TODO: raise an error
	}
	for {set i 1} {$i <= 4} {incr i} {
	    $moduleObj varset kpoints($ia,$i) -value [lindex $_line [expr $i - 1]]
	}
    }
}


# ------------------------------------------------------------------------
#  ::pwscf::pwReadFilter --
# ------------------------------------------------------------------------

proc ::pwscf::pwReadFilter {moduleObj channel} {
    variable pwscf

    # clear the head & tail
    set pwscf($moduleObj,inputHeadContent) {}
    #set pwscf($moduleObj,inputTailContent) {}
    set pwscf($moduleObj,OCCUPATIONS)      {}

    #
    # check if lattice is specified by celldm() or A,B,C,...
    #
    set system 0
    while { ! [eof $channel] } {
	gets $channel _line
	if { [string match -nocase "*&SYSTEM*" $_line] } {
	    set system 1
	    continue
	}
	if { $system } {
	    if { [regexp -nocase -- $::guib::settings(NAMELIST.end_regexp) $_line] } {
		break
	    }
	    append SYSTEM_namelist_content ${_line}\n
	}
    }
    foreach record [split $SYSTEM_namelist_content ,\n] {
	set var [lindex [split $record =] 0]
	if { [::tclu::stringMatch celldm* $var $::guib::settings(INPUT.nocase)] } {
	    varset how_lattice -value celldm
	} elseif  { [::tclu::stringMatch A $var $::guib::settings(INPUT.nocase)] } {
	    varset how_lattice -value abc
	}
    }    
    seek $channel 0 start

    #
    # check if there are non-empty lines before starting &CONTROL
    # namelist
    # 
    while {1} {
	set res [gets $channel _line]
	if { $res == -1 && $_line == "" } {
	    # end of file occurred
	    ::tclu::ERROR "end of file occurred, while reading PW.X input"
	    return -code return
	}	
	if { [string match -nocase "*&CONTROL*" $_line] } {
	    # we found "&CONTROL" line
	    set Line(1)  $_line
	    break
	} else {
	    append pwscf($moduleObj,inputHeadContent) "$_line\n"
	}
    }
    

    # Re-order the cards in the following order:
    # --------------------------------------------------

    #   CELL_PARAMETERS
    #   ATOMIC_SPECIES
    #   ATOMIC_POSITIONS
    #   K_POINTS
    #   CLIMBING_IMAGES

    # The content of OCCUPATIONS card is managed by the "text"
    # keyword, hence we have to store the content of OCCUPATIONS

    set what  {}
    set ind   1
    set _read 1
    
    while {1} {
	if { $_read } {
	    set res [gets $channel _line]
	    if { $res == -1 && $_line == "" } {
		# end of file occurred
		break
	    }    
	}
	if { [string match "CELL_PARAMETERS*" $_line] } {	    
	    set what CELL_PARAMETERS	    
	    set _line [readFilter::purifyCardLine $_line]	    
	} elseif { [string match "ATOMIC_SPECIES*" $_line] } {
	    set what ATOMIC_SPECIES	    
	    set _line [readFilter::purifyCardLine $_line]
	} elseif { [string match "ATOMIC_POSITIONS*" $_line] } {
	    set what ATOMIC_POSITIONS	    
	    set _line [readFilter::purifyCardLine $_line]
	} elseif { [string match "K_POINTS*" $_line] } {
	    set what K_POINTS
	    set _line [readFilter::purifyCardLine $_line]
	} elseif { [string match "OCCUPATIONS*" $_line] } {
	    set what OCCUPATIONS
	    set _line [readFilter::purifyCardLine $_line]
	} elseif { [string match "CLIMBING_IMAGES*" $_line] } {
	    set what CLIMBING_IMAGES
	    set _line [readFilter::purifyCardLine $_line]
	}
	
	if { $what == {} } {	    
	    # VARIABLE: occupations; handle multiple flags
	    #---------------------------------------------
	    # 'gaussian', 'gauss'                       --> 'gaussian'
	    # 'methfessel-paxton', 'm-p', 'mp'          --> 'methfessel-paxton'
	    # 'marzari-vanderbilt', 'cold', 'm-v', 'mv' --> 'marzari-vanderbilt'
	    # 'fermi-dirac', 'f-d', 'fd'                --> 'fermi-dirac'
	    set _line [readFilter::replaceFlag $_line gaussian gauss]
	    set _line [readFilter::replaceFlag $_line methfessel-paxton m-p mp]
	    set _line [readFilter::replaceFlag $_line marzari-vanderbilt cold m-v mv]
	    set _line [readFilter::replaceFlag $_line fermi-dirac f-d fd]
    
	    # VARIABLE: diagonalization; handle multiple flags
	    #-------------------------------------------------
	    # 'david' 'david_overlap' 'david_nooverlap' --> 'david'
	    set _line [readFilter::replaceFlag $_line david david_overlap david_nooverlap]

	    # logical VARIABLES: use only .true. and .false.
	    #-----------------------------------------------
	    set _line [readFilter::logicalFlag $_line]

	    incr ind
	    set Line($ind) $_line
	} else {
	    # fortranreal --> real translation
	    regsub -all -nocase {([0-9]|[0-9].)(d)([+-]?[0-9]+)} $_line {\1e\3} _transline
	    if { ! [string match "OCCUPATIONS*" $_line] } {
		# the OCCUPATIONS are treated specially (see below)
		append $what "$_transline\n"
	    }
	}
	set _read 1
    }

    # close the old channel
    close $channel

    # open a new channel (i.e. temporary file)     
    set tmpfile    [::tclu::tempFile name pw_input]
    set newChannel [open $tmpfile w+]

    #
    # write the file:
    # ---------------
    # write the namelists
    for {set i 1} {$i <= $ind} {incr i} {
	puts $newChannel $Line($i)
    }
    # write the CELL_PARAMETERS
    if { [info exists CELL_PARAMETERS] } {
	puts $newChannel $CELL_PARAMETERS
    }
    # write the ATOMIC_SPECIES
    if { [info exists ATOMIC_SPECIES] } {
	puts $newChannel $ATOMIC_SPECIES
    }
    # write the ATOMIC_POSITIONS
    if { [info exists ATOMIC_POSITIONS] } {
	puts $newChannel $ATOMIC_POSITIONS
    }    
    # write the K_POINTS
    if { [info exists K_POINTS] } {
	puts $newChannel $K_POINTS
    }
    # write the CLIMBING_IMAGES
    if { [info exists CLIMBING_IMAGES] } {
	puts $newChannel $CLIMBING_IMAGES
    }
    # store the OCCUPATIONS record
    if { [info exists OCCUPATIONS] } {
	puts $newChannel "OCCUPATIONS\n"
	set pwscf($moduleObj,OCCUPATIONS) $OCCUPATIONS
    }
    flush $newChannel

    # rewind the newChannel
    seek $newChannel 0 start
    return $newChannel
}


# ------------------------------------------------------------------------
#  ::pwscf::pwWriteFilter --
# ------------------------------------------------------------------------

proc ::pwscf::pwWriteFilter {moduleObj outputContent} {
    variable pwscf
    # HEAD
    if { [info exists pwscf($moduleObj,inputHeadContent)] } {
	append output $pwscf($moduleObj,inputHeadContent)
    }
    # BODY
    append output $outputContent
    # TAIL
    #if { [info exists pwscf($moduleObj,inputTailContent)] } {
    #	append output $pwscf($moduleObj,inputTailContent)
    #}
    return $output    
}


# ------------------------------------------------------------------------
# Reads next non-empty line from channel. If EOF occurs, then it
# returns return-code.
# ------------------------------------------------------------------------
proc ::pwscf::_getsNonEmptyLine {channel} {
    # while loop for skipping empty lines !!!
    while {1} {
	set res [gets $channel _line]
	if { $res == -1 && $_line == "" } {
	    # end of file occurred
	    return -code return
	}    
	if { [llength $_line] != 0 } {
	    return $_line
	}
    }
}

