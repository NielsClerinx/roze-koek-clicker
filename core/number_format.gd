class_name NumberFormat
extends RefCounted
## Schaalbare getalnotatie: 1.234 -> "1.234", 1,5 miljoen -> "1,50 M", enz.
## Na de laatste afkorting schakelt het over naar wetenschappelijke notatie.

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg"]

static func format(value: float, decimals_small: bool = false) -> String:
	if is_nan(value):
		return "0"
	if is_inf(value):
		return "∞"
	var neg := value < 0.0
	var v := absf(value)
	var out: String
	if v < 1000.0:
		if decimals_small and v < 100.0 and absf(v - roundf(v)) > 0.001:
			out = _comma("%.1f" % v)
		else:
			out = _thousands(int(floor(v)))
	elif v < 1e6:
		out = _thousands(int(floor(v)))
	else:
		var tier := int(floor(log(v) / log(1000.0)))
		if tier >= SUFFIXES.size():
			var exp10 := int(floor(log(v) / log(10.0)))
			out = _comma("%.2f" % (v / pow(10.0, exp10))) + "e" + str(exp10)
		else:
			var scaled := v / pow(1000.0, tier)
			# Afrondingsfout opvangen (999,999 M -> 1,00 B)
			if scaled >= 999.995:
				tier += 1
				scaled /= 1000.0
				if tier >= SUFFIXES.size():
					return format(value * 1.0000001, decimals_small)
			var txt: String
			if scaled < 10.0:
				txt = "%.2f" % scaled
			elif scaled < 100.0:
				txt = "%.1f" % scaled
			else:
				txt = "%d" % int(floor(scaled))
			out = _comma(txt) + " " + SUFFIXES[tier]
	return ("-" if neg else "") + out

static func duration(seconds: float) -> String:
	var s := int(max(seconds, 0.0))
	var h := s / 3600
	var m := (s % 3600) / 60
	if h > 0:
		return "%d u %02d min" % [h, m]
	if m > 0:
		return "%d min %02d s" % [m, s % 60]
	return "%d s" % s

static func _comma(s: String) -> String:
	return s.replace(".", ",")

static func _thousands(n: int) -> String:
	var s := str(n)
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "." + res
	return res
