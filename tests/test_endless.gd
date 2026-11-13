extends "res://tests/test_case.gd"

const Endless = preload("res://scripts/endless.gd")
const Progress = preload("res://scripts/progress.gd")
const LevelLoader = preload("res://scripts/level_loader.gd")

const CAMPAIGN := 60


func _sum(rewards: Array, power: String) -> int:
	var total := 0
	for r in rewards:
		total += int(r.reward.get(power, 0))
	return total


func _kinds(rewards: Array) -> Array:
	return rewards.map(func(r): return r.kind)


func test_bosses_every_10_levels() -> void:
	var bosses := []
	for n in range(55, 101):
		if Endless.is_boss(n):
			bosses.append(n)
	assert_eq(bosses, [70, 80, 90, 100], "chefes só no modo infinito, a cada 10")
	assert_eq(Endless.next_boss(61), 70)
	assert_eq(Endless.next_boss(70), 70, "a própria fase, se for chefe")
	assert_eq(Endless.next_boss(71), 80)
	for n in [70, 80, 90]:
		var level := Endless.level_for(n)
		assert_true(level.get("boss", false), "fase %d é chefe" % n)
		assert_true(LevelLoader.build_session(level).board.has_moves(), "chefe %d jogável" % n)
	assert_false(Endless.level_for(71).has("boss"))
	var three: Dictionary = Endless.level_for(90).goal
	assert_eq(three.type, "colors")
	assert_eq(three.targets.size(), 3, "chefe de três cores")


func test_ranks() -> void:
	assert_eq(Endless.rank_index(0), -1)
	assert_eq(Endless.rank_index(69), -1)
	assert_eq(Endless.rank_index(70), 0, "Bronze")
	assert_eq(Endless.rank_index(99), 1, "Prata")
	assert_eq(Endless.rank_index(100), 2, "Ouro")
	assert_eq(Endless.rank_index(5000), Endless.RANKS.size() - 1)
	for r in Endless.RANKS:
		assert_true(Endless.is_boss(int(r.level)), "patente %s vem de um chefe" % r.name)


func test_chest_prize_is_fixed_and_valid() -> void:
	var counts := {}
	for n in range(1, 401):
		var prize := Endless.chest_prize(n)
		assert_eq(prize, Endless.chest_prize(n), "sorteio fixo por número")
		assert_true(_sum([{"reward": prize}], "hammer") + _sum([{"reward": prize}], "swap") > 0, "baú %d vazio" % n)
		counts[str(prize)] = int(counts.get(str(prize), 0)) + 1
	assert_eq(counts.size(), Endless.CHEST_PRIZES.size(), "todos os prêmios aparecem")


func test_boss_and_rank_rewards() -> void:
	var p := Progress.new()
	for n in range(1, CAMPAIGN + 1):
		p.record_result(n, 1)
	for n in range(61, 70):
		p.record_result(n, 1)
		var expected := ["streak"] if n == 65 else []  # 5 vitórias seguidas
		assert_eq(_kinds(p.claim_endless_rewards(n, true, CAMPAIGN)), expected, "fase comum (%d)" % n)
	var hammers := p.power_count("hammer")
	p.record_result(70, 2)
	var rewards := p.claim_endless_rewards(70, true, CAMPAIGN)
	assert_eq(_kinds(rewards), ["boss", "rank", "streak"], "chefe 70, patente Bronze e 10 seguidas")
	assert_eq(p.power_count("hammer"), hammers + _sum(rewards, "hammer"), "poderes somados")
	p.record_result(70, 3)
	assert_eq(p.claim_endless_rewards(70, false, CAMPAIGN), [], "repetir o chefe não dá de novo")


func test_ranks_are_claimed_once_even_if_skipped() -> void:
	var p := Progress.new()
	p.record_result(100, 1)  # save antigo que já tinha passado da 100
	var rewards := p.claim_endless_rewards(100, false, CAMPAIGN)
	assert_eq(_kinds(rewards), ["rank", "rank", "rank"], "Bronze, Prata e Ouro de uma vez")
	assert_eq(p.rank_claimed, 2)
	p.record_result(101, 1)
	assert_eq(p.claim_endless_rewards(101, true, CAMPAIGN), [])


func test_chest_opens_every_30_endless_stars() -> void:
	var p := Progress.new()
	for n in range(1, CAMPAIGN + 1):
		p.record_result(n, 3)  # estrelas da campanha não contam
	assert_eq(p.chest_stars(CAMPAIGN), 0)
	for n in range(61, 70):
		p.record_result(n, 3)
		p.claim_endless_rewards(n, true, CAMPAIGN)
	assert_eq(p.chest_stars(CAMPAIGN), 27)
	p.record_result(70, 3)  # 30 estrelas: abre (e a 70 é chefe)
	var rewards := p.claim_endless_rewards(70, true, CAMPAIGN)
	assert_eq(_kinds(rewards), ["boss", "rank", "chest", "streak"])
	assert_eq(rewards[2].reward, Endless.chest_prize(1))
	assert_eq(p.chests_opened, 1)
	assert_eq(p.chest_stars(CAMPAIGN), 0, "baú recomeça")
	var q := Progress.new()
	q.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(q.chests_opened, 1, "salvo")
	assert_eq(q.rank_claimed, p.rank_claimed)
	assert_eq(q.chest_stars(CAMPAIGN), 0)
	var fresh = q.reset_keeping_settings()
	assert_eq(fresh.chests_opened, 0, "apagar progresso zera o baú")
	assert_eq(fresh.rank_claimed, -1)


func test_win_streak() -> void:
	var p := Progress.new()
	for n in range(61, 65):
		p.record_result(n, 1)
		p.claim_endless_rewards(n, true, CAMPAIGN)
	assert_eq(p.streak, 4)
	p.streak_pending = true
	p.claim_endless_rewards(61, false, CAMPAIGN)  # repetir fase vencida
	assert_eq(p.streak, 4, "repetir fase já vencida não conta")
	assert_false(p.streak_pending, "vitória encerra a tentativa")
	var hammers := p.power_count("hammer")
	p.record_result(65, 1)
	var rewards := p.claim_endless_rewards(65, true, CAMPAIGN)
	assert_eq(_kinds(rewards), ["streak"])
	assert_eq(int(rewards[0].count), 5)
	assert_eq(p.power_count("hammer"), hammers + int(Endless.STREAK_REWARD.hammer))
	assert_eq(p.break_streak(), 5, "derrota devolve a sequência perdida")
	assert_eq(p.streak, 0)
	assert_eq(p.streak_best, 5, "recorde fica")
	p.streak = 3
	p.streak_pending = true
	var q := Progress.new()
	q.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq([q.streak, q.streak_best, q.streak_pending], [3, 5, true], "salvo")
	var fresh = q.reset_keeping_settings()
	assert_eq([fresh.streak, fresh.streak_best, fresh.streak_pending], [0, 0, false])
