## Base mínima para testes (sem plugins). Cada método "test_*" é executado
## por tests/run_tests.gd; falhas são acumuladas em [member failures].
extends RefCounted

var failures: Array[String] = []


func assert_true(value: bool, msg: String = "") -> void:
	if not value:
		failures.append("esperava verdadeiro. %s" % msg)


func assert_false(value: bool, msg: String = "") -> void:
	if value:
		failures.append("esperava falso. %s" % msg)


func assert_eq(actual, expected, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("esperado %s, obtido %s. %s" % [var_to_str(expected), var_to_str(actual), msg])
