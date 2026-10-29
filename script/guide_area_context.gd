extends RefCounted

# Authored observations and plausible inferences, without hidden quest requirements.
const ZONES: Dictionary = {
	"bong": {
		"ru": "Рядом Конг — большой орангутан. Его намерения, характер и прошлое тебе неизвестны.",
		"cz": "Poblíž je Kong, velký orangutan. Jeho úmysly, povahu ani minulost neznáš.",
		"aliases": ["конг", "bong", "kong"],
	},
	"flycatcher": {
		"ru": "Рядом крупная мухоловка, растение с заметными ловушками. Ты не знаешь её намерений и свойств.",
		"cz": "Poblíž je velká mucholapka, rostlina s nápadnými pastmi. Její úmysly ani vlastnosti neznáš.",
		"aliases": ["мухолов", "mucholap"],
	},
	"panda": {
		"ru": "Рядом панда. Ты видишь её здесь, но не знаешь её характер, биографию и планы.",
		"cz": "Poblíž je panda. Vidíš ji tady, ale neznáš její povahu, minulost ani plány.",
		"aliases": ["панд", "panda", "pandu", "pandě"],
	},
	"baobab": {
		"ru": "Рядом большой баобаб с толстым стволом. Его точный возраст и история неизвестны.",
		"cz": "Poblíž je velký baobab se silným kmenem. Jeho přesné stáří ani historii neznáš.",
		"aliases": ["баобаб", "баубаб", "дерев", "ствол", "baobab", "strom", "kmen"],
	},
	"beach": {
		"ru": "Вы на пляже: видны песчаный берег и море. Ты не знаешь, что находится за морем.",
		"cz": "Jste na pláži, vidíš písečný břeh a moře. Nevíš, co leží za mořem.",
		"aliases": ["пляж", "берег", "pláž", "břeh"],
	},
	"paths": {
		"ru": "Рядом видны тропинки, уходящие дальше среди растительности. Куда именно они ведут, ты не знаешь.",
		"cz": "Poblíž vidíš pěšiny vedoucí dál mezi rostlinami. Nevíš, kam přesně vedou.",
		"aliases": ["троп", "дорож", "pěšin", "stezk", "cest"],
	},
	"ship": {
		"ru": "У берега разбитый корабль с видимыми повреждениями. Чтобы попробовать уплыть на нём с острова, вероятно, нужно его починить. Кто его оставил и какие конкретно детали нужны — тебе неизвестно.",
		"cz": "U břehu je rozbitá loď s viditelným poškozením. Abychom na ní mohli zkusit odplout z ostrova, nejspíš ji musíme opravit. Nevíš, kdo ji tu nechal ani jaké přesně součástky potřebuje.",
		"aliases": ["лодк", "кораб", "loď", "lod", "člun"],
	},
}

const LINES: Dictionary = {
	"bong": {
		"ru": ["Смотри, это Конг. Он просто огромный.", "Вот и Конг. Интересно, какой он в разговоре.", "Конг рядом. Ты уже с ним говорил?", "Ого, какой большой орангутан.", "Необычно встретить здесь орангутана.", "Как думаешь, Конг захочет с нами поговорить?"],
		"cz": ["Podívej, Kong. Ten je ale velký.", "Tak tady je Kong. Zajímalo by mě, jaké by bylo si s ním povídat.", "Kong je poblíž. Už jsi s ním mluvil?", "Ten orangutan je opravdu velký.", "Orangutana jsem tady nečekal.", "Myslíš, že by si s námi Kong popovídal?"],
	},
	"flycatcher": {
		"ru": ["Ого, какая большая мухоловка. С такими ловушками она выглядит опасно.", "Вот это ловушки. Не хотел бы случайно в них попасть.", "Ого, какая крупная мухоловка.", "Необычное растение. Эти ловушки сразу бросаются в глаза.", "Эта мухоловка выглядит внушительно.", "Смотри, мухоловка с такими заметными ловушками."],
		"cz": ["To je ale velká mucholapka. S takovými pastmi působí nebezpečně.", "To jsou ale pasti. Nerad bych do nich omylem spadl.", "To je ale velká mucholapka.", "Neobvyklá rostlina. Ty pasti hned upoutají pozornost.", "Ta mucholapka působí impozantně.", "Podívej, mucholapka s tak nápadnými pastmi."],
	},
	"panda": {
		"ru": ["Смотри, панда. Интересно, она может нам что-нибудь подсказать?", "Здесь панда. Интересно, как она отнесётся к нам.", "Панда совсем рядом. Ты уже с ней говорил?", "Необычно встретить здесь панду.", "Я вижу панду. Интересно, что она о нас думает.", "Вот панда. Как думаешь, с ней можно поговорить?"],
		"cz": ["Podívej, panda. Myslíš, že by nám mohla něco poradit?", "Je tu panda. Zajímalo by mě, jak na nás zareaguje.", "Panda je blízko. Už jsi s ní mluvil?", "Neobvyklé místo na setkání s pandou.", "Vidím pandu. Zajímalo by mě, co si o nás myslí.", "Tady je panda. Myslíš, že by si s námi popovídala?"],
	},
	"baobab": {
		"ru": ["Ничего себе, какой толстый ствол у этого баобаба.", "Большой баобаб. Трудно его не заметить.", "Смотри, баобаб. Какой же у него широкий ствол.", "Такой баобаб сразу бросается в глаза.", "У этого баобаба впечатляющий ствол.", "Вот это дерево. Интересно, сколько ему лет."],
		"cz": ["Ten baobab má opravdu silný kmen.", "Velký baobab. Toho si nejde nevšimnout.", "Podívej na ten baobab. Jak široký má kmen.", "Takový baobab hned upoutá pozornost.", "Ten baobab má působivý kmen.", "To je strom. Zajímalo by mě, jak je starý."],
	},
	"beach": {
		"ru": ["А вот и пляж. Море совсем рядом.", "Вот мы и на пляже.", "Отсюда видно море.", "Смотри, песчаный берег. А рядом море.", "Перед нами пляж и море.", "Тут пляж. Интересно, что там, за морем."],
		"cz": ["Tak tady je pláž. Moře je hned vedle.", "Tak jsme na pláži.", "Odtud je vidět moře.", "Podívej, písečný břeh. A vedle něj moře.", "Před námi je pláž a moře.", "Je tu pláž. Zajímalo by mě, co je za mořem."],
	},
	"paths": {
		"ru": ["Тропинки. Наверное, по ним можно куда-нибудь выйти.", "Тропинки уходят дальше среди растений.", "Вот тропинки. Интересно, что там дальше.", "Здесь есть тропинки, но куда они ведут, я не знаю.", "Эти дорожки куда-то ведут. Интересно, куда именно.", "Смотри, тропинки среди растительности."],
		"cz": ["Pěšiny. Možná nás někam dovedou.", "Pěšiny pokračují dál mezi rostlinami.", "Tady jsou pěšiny. Zajímalo by mě, co je dál.", "Jsou tu pěšiny, ale nevím, kam vedou.", "Ty cesty někam vedou. Zajímalo by mě kam.", "Podívej, pěšiny mezi rostlinami."],
	},
	"ship": {
		"ru": ["Разбитый корабль. Наверное, чтобы уплыть с острова, надо его починить.", "Похоже, корабль повреждён. Если хотим уплыть, без ремонта, наверное, не обойтись.", "Смотри, разбитый корабль у берега. Может, после ремонта на нём получится уплыть.", "Корабль пострадал. Интересно, сможем ли мы его починить и выбраться отсюда.", "У берега разбитый корабль. Возможно, это наш шанс уплыть, если привести его в порядок.", "С таким повреждением далеко не уплывёшь. Наверное, сначала нужен ремонт."],
		"cz": ["Rozbitá loď. Asi ji budeme muset opravit, abychom mohli odplout z ostrova.", "Ta loď je poškozená. Jestli chceme odplout, bez opravy to asi nepůjde.", "Podívej, rozbitá loď u břehu. Možná bychom na ní po opravě mohli odplout.", "Loď je poškozená. Zajímalo by mě, jestli ji zvládneme opravit a dostat se odsud.", "U břehu je rozbitá loď. Možná je to naše šance odplout, pokud ji dáme do pořádku.", "S takovým poškozením daleko nedoplujeme. Nejdřív bude asi potřeba oprava."],
	},
}


static func facts(zone: String, czech: bool, ship_repaired: bool = false) -> String:
	if zone == "ship" and ship_repaired:
		return "Loď u břehu už je opravená. Mohli bychom na ní zkusit odplout z ostrova." if czech else "Корабль у берега уже отремонтирован. На нём можно попробовать уплыть с острова."
	return str(ZONES.get(zone, {}).get("cz" if czech else "ru", ""))


static func lines(zone: String, czech: bool, ship_repaired: bool = false) -> Array:
	if zone == "ship" and ship_repaired:
		return ["Loď už je opravená. Možná se konečně dostaneme z ostrova.", "Vypadá to, že je loď připravená. Teď bychom mohli zkusit odplout.", "Loď je zase v pořádku. Třeba je to naše cesta z ostrova."] if czech else ["Корабль уже починен. Может, теперь получится выбраться с острова.", "Похоже, корабль готов. Теперь можно попробовать уплыть.", "Корабль снова в порядке. Возможно, это наш путь с острова."]
	return LINES.get(zone, {}).get("cz" if czech else "ru", []).duplicate()


static func age_answers(czech: bool) -> Array:
	if czech:
		return ["Nevím, kolik mu je let. Vidím jen, že má opravdu silný kmen.", "Přesné stáří neznám. Podle vzhledu bych ho neodhadoval.", "Stáří neznám, ale ten baobab je opravdu velký.", "Nevím. Samotný silný kmen přesné stáří neprozradí."]
	return ["Не знаю, сколько ему лет. Видно только, что ствол очень толстый.", "Точный возраст мне неизвестен. По одному виду я бы его не угадывал.", "Возраст не знаю. Но баобаб и правда большой.", "Не знаю. Сам по себе толстый ствол точного возраста не говорит."]


static func mentions_zone(value: String, zones: Array[String]) -> bool:
	var normalized := value.to_lower()
	for zone: String in zones:
		for alias: String in ZONES.get(zone, {}).get("aliases", []):
			if normalized.contains(alias):
				return true
	return false
