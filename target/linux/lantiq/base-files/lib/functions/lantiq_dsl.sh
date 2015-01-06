#!/bin/sh /etc/rc.common
# Copyright (C) 2012 OpenWrt.org

XDSL_CTRL=dsl_cpe_control

header="%-25s %-13s %-13s\n"

#
# Basic functions to send CLI commands to the vdsl_cpe_control daemon
#
dsl_cmd() {
	killall -0 ${XDSL_CTRL} && (
		echo "$@" > /tmp/pipe/dsl_cpe0_cmd
		cat /tmp/pipe/dsl_cpe0_ack
	)
}
dsl_val() {
	echo $(expr "$1" : '.*'$2'=\([-\.[:alnum:]]*\).*')
}

#
# Simple divide by 10 routine to cope with one decimal place
#
dbt() {
	local a=$(expr $1 / 10)
	local b=$(expr $1 % 10)
	echo "${a}.${b}"
}

#
# Simple divide by 100 routine to cope with one decimal place
#
dbh() {
	local a=$(expr $1 / 100)
	local b=$(expr $1 % 100)
	echo "${a}.${b}"
}

#
# Take a number and convert to k or meg
#
scale() {
	local val=$1
	local a
	local b

	if [ "$val" -gt 1000000 ]; then
		a=$(expr $val / 1000)
		b=$(expr $a % 1000)
		a=$(expr $a / 1000)
		printf "%d.%03d Mb" ${a} ${b}
	elif [ "$val" -gt 1000 ]; then
		a=$(expr $val / 1000)
		printf "%d Kb" ${a}
	else
		echo "${val} b"
	fi
}

#
# Read the data rates for both directions
#
data_rates() {
	local csg
	local lsg
	local dru
	local drd
	local adru
	local adrd
	local sdru
	local sdrd
	local sadru
	local sadrd
	
	divider============================
	divider=$divider$divider

	csg=$(dsl_cmd g997csg 0 1)
	drd=$(dsl_val "$csg" ActualDataRate)

	csg=$(dsl_cmd g997csg 0 0)
	dru=$(dsl_val "$csg" ActualDataRate)

	lsg=$(dsl_cmd g997lsg 1 1)
	adrd=$(dsl_val "$lsg" ATTNDR)

	lsg=$(dsl_cmd g997lsg 0 1)
	adru=$(dsl_val "$lsg" ATTNDR)

	[ -z "$drd" ] && drd=0
	[ -z "$dru" ] && dru=0
	[ -z "$adrd" ] && adrd=0
	[ -z "$adru" ] && adru=0

	sdrd=$(scale $drd)
	sdru=$(scale $dru)
	sadrd=$(scale $adrd)
	sadru=$(scale $adru)

	if [ "$action" = "lucistat" ]; then
		echo "dsl.data_rate_down=$drd"
		echo "dsl.data_rate_up=$dru"
		echo "dsl.data_rate_down_s=\"$sdrd\""
		echo "dsl.data_rate_up_s=\"$sdru\""
		echo "dsl.att_data_rate_down=\"$adrd\""
		echo "dsl.att_data_rate_up=\"$adru\""
		echo "dsl.att_data_rate_down_s=\"$sadrd\""
		echo "dsl.att_data_rate_up_s=\"$sadru\""
	else
		printf "\n$header" "" "DOWNSTREAM" "UPSTREAM"		
		printf "$divider\n"
		printf "$header" "Actual Data Rate:" "${sdrd}/s" "${sdru}/s"
		printf "$header" "Attainable Data Rate:" "${sadrd}/s" "${sadru}/s"
	fi
}

#
# Chipset
#
chipset() {
	local vig
	local listrg
	local cs
	local csv
	local csfw
	local vid
	local svid
	local vvn

	vig=$(dsl_cmd vig)
	listrg=$(dsl_cmd g997listrg 1)
	cs=$(dsl_val "$vig" DSL_ChipSetType)
	csv=$(dsl_val "$vig" DSL_ChipSetHWVersion)
	csfw=$(dsl_val "$vig" DSL_ChipSetFWVersion)
	vid=$(dsl_val "$listrg" G994VendorID)
	svid=$(dsl_val "$listrg" SystemVendorID)
	vvn=$(dsl_val "$listrg" VersionNumber)

	if [ "$action" = "lucistat" ]; then
		echo "dsl.chipset=\"${cs} ${csv}\""
		echo "dsl.co.chipset=\"${vid} / ${svid} ${vvn}\""
	else
		echo "CPE Chipset:	    ${cs} ${csv} / dsl fw: ${csfw}"
		echo "CO vendor Info:	    ${vid} / ${svid} ${vvn}"
	fi
}

#
# Work out how long the line has been up
#
line_uptime() {
	local ccsg
	local et
	local etr
	local d
	local h
	local m
	local s
	local rc=""

	ccsg=$(dsl_cmd pmccsg 0 0 0)
	et=$(dsl_val "$ccsg" nElapsedTime)

	[ -z "$et" ] && et=0

	if [ "$action" = "lucistat" ]; then
		echo "dsl.line_uptime=${et}"
		return
	fi

	d=$(expr $et / 86400)
	etr=$(expr $et % 86400)
	h=$(expr $etr / 3600)
	etr=$(expr $etr % 3600)
	m=$(expr $etr / 60)
	s=$(expr $etr % 60)


	[ "${d}${h}${m}${s}" -ne 0 ] && rc="${s}s"
	[ "${d}${h}${m}" -ne 0 ] && rc="${m}m ${rc}"
	[ "${d}${h}" -ne 0 ] && rc="${h}h ${rc}"
	[ "${d}" -ne 0 ] && rc="${d}d ${rc}"

	[ -z "$rc" ] && rc="down"
	echo "Line Uptime:	    ${rc}"
}

#
# Get noise, power and attenuation figures
#
line_data() {
	local lsg
	local latnu
	local latnd
	local snru
	local snrd
	local satnu
	local satnd
	local tpd
	local tpu

	lsg=$(dsl_cmd g997lsg 1 1)
	latnd=$(dsl_val "$lsg" LATN)
	snrd=$(dsl_val "$lsg" SNR)
	satnd=$(dsl_val "$lsg" SATN)
	tpd=$(dsl_val "$lsg" ACTATP)

	lsg=$(dsl_cmd g997lsg 0 1)
	latnu=$(dsl_val "$lsg" LATN)
	snru=$(dsl_val "$lsg" SNR)
	satnu=$(dsl_val "$lsg" SATN)
	tpu=$(dsl_val "$lsg" ACTATP)

	[ -z "$latnd" ] && latnd=0
	[ -z "$latnu" ] && latnu=0
	[ -z "$snrd" ] && snrd=0
	[ -z "$snru" ] && snru=0
	[ -z "$satnd" ] && satnd=0
	[ -z "$satnu" ] && satnu=0
	[ -z "$tpu" ] && tpu=0
	[ -z "$tpd" ] && tpd=0

	latnd=$(dbt $latnd)
	latnu=$(dbt $latnu)
	snrd=$(dbt $snrd)
	snru=$(dbt $snru)
	satnd=$(dbt $satnd)
	satnu=$(dbt $satnu)
	tpd=$(dbt $tpd)
	tpu=$(dbt $tpu)
	
	if [ "$action" = "lucistat" ]; then
		echo "dsl.line_attenuation_down=$latnd"
		echo "dsl.line_attenuation_up=$latnu"
		echo "dsl.signal_attenuation_down=$satnd"
		echo "dsl.signal_attenuation_up=$satnu"
		echo "dsl.noise_margin_down=$snrd"
		echo "dsl.noise_margin_up=$snru"
		echo "dsl.transmit_power_down=$tpd"
		echo "dsl.transmit_power_up=$tpu"
	else
		printf "$header" "Line Attenuation:" "${latnd} dB" "${latnu} dB" \
		"Signal Attenuation:" "${satnd} dB" "${satnu} dB" \
		"Noise Margin:" "${snrd} dB" "${snru} dB" \
		"Transmit Power:" "${tpd} dBm" "${tpu} dBm"
	fi
}

#
# Get misc line figures
#
line_data_extended() {
	local csg
	local dpcsg
	local ccsg
	local dpc15mg
	local did
	local uid
	local dinp
	local uinp
	local hecd
	local hecu
	local crcd
	local crcu
	local fecd
	local fecu
	local hec15d
	local hec15u
	local crc15d
	local crc15u
	local fec15d
	local fec15u

	csg=$(dsl_cmd g997csg 0 1)
	idd=$(dsl_val "$csg" ActualInterleaveDelay)
	inpd=$(dsl_val "$csg" ActualImpulseNoiseProtection)

	csg=$(dsl_cmd g997csg 0 0)
	idu=$(dsl_val "$csg" ActualInterleaveDelay)
	inpu=$(dsl_val "$csg" ActualImpulseNoiseProtection)

	dpcsg=$(dsl_cmd pmdpcsg 0 0 0)
	hecd=$(dsl_val "$dpcsg" nHEC)
	crcd=$(dsl_val "$dpcsg" nCRC_P)

	dpcsg=$(dsl_cmd pmdpcsg 0 1 0)
	hecu=$(dsl_val "$dpcsg" nHEC)
	crcu=$(dsl_val "$dpcsg" nCRC_P)

	dpc15mg=$(dsl_cmd pmdpc15mg 0 0 0)
	hec15d=$(dsl_val "$dpc15mg" nHEC)
	crc15d=$(dsl_val "$dpc15mg" nCRC_P)

	dpc15mg=$(dsl_cmd pmdpc15mg 0 1 0)
	hec15u=$(dsl_val "$dpc15mg" nHEC)
	crc15u=$(dsl_val "$dpc15mg" nCRC_P)

	ccsg=$(dsl_cmd pmccsg 0 0 0)
	fecd=$(dsl_val "$ccsg" nFEC)

	ccsg=$(dsl_cmd pmccsg 0 1 0)
	fecu=$(dsl_val "$ccsg" nFEC)

	cc15mg=$(dsl_cmd pmcc15mg 0 0 0)
	fec15d=$(dsl_val "$cc15mg" nFEC)

	cc15mg=$(dsl_cmd pmcc15mg 0 1 0)
	fec15u=$(dsl_val "$cc15mg" nFEC)

	[ -z "$idd" ] && idd=0
	[ -z "$idu" ] && idu=0
	[ -z "$inpd" ] && inpd=0
	[ -z "$inpu" ] && inpu=0
	[ -z "$hecd" ] && hecd=-1
	[ -z "$hecu" ] && hecu=-1
	[ -z "$crcd" ] && crcd=-1
	[ -z "$crcu" ] && crcu=-1
	[ -z "$fecd" ] && fecd=-1
	[ -z "$fecu" ] && fecu=-1

	[ -z "$hec15d" ] && hec15d=-1
	[ -z "$hec15u" ] && hec15u=-1
	[ -z "$crc15d" ] && crc15d=-1
	[ -z "$crc15u" ] && crc15u=-1
	[ -z "$fec15d" ] && fec15d=-1
	[ -z "$fec15u" ] && fec15u=-1

	idd=$(dbh $idd)
	idu=$(dbh $idu)
	inpd=$(dbt $inpd)
	inpu=$(dbt $inpu)

	if [ "$action" = "lucistat" ]; then
		echo "dsl.interleave_delay_down_ms=\"$idd\""
		echo "dsl.interleave_delay_up_ms=\"$idu\""
		echo "dsl.impulse_np_down_sym=\"$inpd\""
		echo "dsl.impulse_np_up_sym=\"$inpu\""
		echo "dsl.hec_errors_down=$hecd"
		echo "dsl.hec_errors_up=$hecu"
		echo "dsl.crc_errors_down=$crcd"
		echo "dsl.crc_errors_up=$crcu"
		echo "dsl.fec_errors_down=$fecd"
		echo "dsl.fec_errors_up=$fecu"
		echo "dsl.hec_errors_15min_down=$hec15d"
		echo "dsl.hec_errors_15min_up=$hec15u"
		echo "dsl.crc_errors_15min_down=$crc15d"
		echo "dsl.crc_errors_15min_up=$crc15u"
		echo "dsl.fec_errors_15min_down=$fec15d"
		echo "dsl.fec_errors_15min_up=$fec15u"
	else
		printf "$header" "Interleave Delay:"	"${idd} ms" "${idu} ms" \
		"INP:" "${inpd} sym" "${inpu} sym" \
		"HEC errors:"	"${hecd}" "${hecu}" \
		"CRC errors:"	"${crcd}" "${crcu}" \
		"FEC errors:"	"${fecd}" "${fecu}" \
		"HEC 15 min errors:"	"${hec15d}" "${hec15u}" \
		"CRC 15 min errors:"	"${crc15d}" "${crc15u}" \
		"FEC 15 min errors:"	"${fec15d}" "${fec15u}"
	fi
}

#
# Is the line up? Or what state is it in?
#
line_state() {
	local lsg=$(dsl_cmd lsg)
	local ls=$(dsl_val "$lsg" nLineState);
	local s;

	case "$ls" in
		"0x0")		s="not initialized" ;;
		"0x1")		s="exception" ;;
		"0x10")		s="not updated" ;;
		"0xff")		s="idle request" ;;
		"0x100")	s="idle" ;;
		"0x1ff")	s="silent request" ;;
		"0x200")	s="silent" ;;
		"0x300")	s="handshake" ;;
		"0x380")	s="full_init" ;;
		"0x400")	s="discovery" ;;
		"0x500")	s="training" ;;
		"0x600")	s="analysis" ;;
		"0x700")	s="exchange" ;;
		"0x800")	s="showtime_no_sync" ;;
		"0x801")	s="showtime_tc_sync" ;;
		"0x900")	s="fastretrain" ;;
		"0xa00")	s="lowpower_l2" ;;
		"0xb00")	s="loopdiagnostic active" ;;
		"0xb10")	s="loopdiagnostic data exchange" ;;
		"0xb20")	s="loopdiagnostic data request" ;;
		"0xc00")	s="loopdiagnostic complete" ;;
		"0x1000000")	s="test" ;;
		"0xd00")	s="resync" ;;
		"0x3c0")	s="short init entry" ;;
		"")		s="not running daemon"; ls="0xfff" ;;
		*)		s="unknown" ;;
	esac

	if [ $action = "lucistat" ]; then
		echo "dsl.line_state_num=$ls"
		echo "dsl.line_state_detail=\"$s\""
		if [ "$ls" = "0x801" ]; then
			echo "dsl.line_state=\"UP\""
		else
			echo "dsl.line_state=\"DOWN\""
		fi
	else
		if [ "$ls" = "0x801" ]; then
			echo "Line State:	    UP [$ls: $s]"
		else
			echo "Line State:	    DOWN [$ls: $s]"
		fi
	fi
}

status() {
	chipset
	line_state
	line_uptime
	data_rates
	line_data
	line_data_extended
}

lucistat() {
	echo "local dsl={}"
	status
	echo "return dsl"
}
