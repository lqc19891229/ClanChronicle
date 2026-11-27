extends Control

const INK = Color("e9dfc8")
const MUTED = Color("a9b2a5")
const GOLD = Color("c5a36a")
const PANEL = Color("202c28")
var date_label: Label
var resource_label: Label
var status_label: Label
var content: VBoxContainer
var nav: VBoxContainer
var timer: Timer
var active_tab: String = "宗族总览"
var selected_id: int = 1
var nav_buttons: Dictionary = {}
var play_button: Button
var speed_button: OptionButton

func _ready() -> void:
    build_ui()
    World.changed.connect(refresh)
    refresh()

func text_label(value: String, size: int = 18, color: Color = INK) -> Label:
    var label = Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func button(value: String, action: Callable) -> Button:
    var item = Button.new()
    item.text = value
    item.custom_minimum_size.y = 38
    item.pressed.connect(action)
    return item

func box_style(color: Color) -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(6)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

func panel(parent: Node, color: Color = PANEL) -> VBoxContainer:
    var frame = PanelContainer.new()
    frame.add_theme_stylebox_override("panel", box_style(color))
    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(frame)
    var inner = VBoxContainer.new()
    inner.add_theme_constant_override("separation", 10)
    frame.add_child(inner)
    return inner

func build_ui() -> void:
    # Use installed CJK fonts; no font binaries are bundled.
    var system_font = SystemFont.new()
    system_font.font_names = PackedStringArray(["Microsoft YaHei", "Microsoft JhengHei", "PingFang SC", "Noto Sans CJK SC", "Noto Sans CJK TC", "WenQuanYi Zen Hei"])
    var ui_theme = Theme.new()
    ui_theme.default_font = system_font
    ui_theme.default_font_size = 17
    theme = ui_theme
    var bg = ColorRect.new()
    bg.color = Color("141d1a")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var margin = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    add_child(margin)
    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 14)
    margin.add_child(root)
    var header = HBoxContainer.new()
    header.add_theme_constant_override("separation", 18)
    root.add_child(header)
    header.add_child(text_label("宗族纪事", 32, GOLD))
    resource_label = text_label("", 18)
    resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(resource_label)
    date_label = text_label("", 20)
    header.add_child(date_label)
    var toolbar = HBoxContainer.new()
    toolbar.add_theme_constant_override("separation", 8)
    root.add_child(toolbar)
    play_button = button("继续", toggle_play)
    toolbar.add_child(play_button)
    speed_button = OptionButton.new()
    speed_button.add_item("慢速 · 每秒1日")
    speed_button.add_item("中速 · 每秒5日")
    speed_button.add_item("快速 · 每秒30日")
    speed_button.select(1)
    toolbar.add_child(speed_button)
    toolbar.add_child(button("+1日", func(): World.advance_days(1)))
    toolbar.add_child(button("+1月", func(): World.advance_days(30)))
    toolbar.add_child(button("+1年", func(): World.advance_days(360)))
    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    toolbar.add_child(spacer)
    toolbar.add_child(button("存档", save_current))
    toolbar.add_child(button("读档", load_current))
    toolbar.add_child(button("新开局", confirm_reset))
    var body = HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 14)
    root.add_child(body)
    var sidebar = PanelContainer.new()
    sidebar.custom_minimum_size.x = 180
    sidebar.add_theme_stylebox_override("panel", box_style(PANEL))
    body.add_child(sidebar)
    nav = VBoxContainer.new()
    nav.add_theme_constant_override("separation", 8)
    sidebar.add_child(nav)
    nav.add_child(text_label("宗族事务", 17, GOLD))
    for tab in ["宗族总览", "人物名册", "房支与家庭", "家谱", "财产账簿", "国家与地区"]:
        var b = button(tab, show_tab.bind(tab))
        b.toggle_mode = true
        nav_buttons[tab] = b
        nav.add_child(b)
    var scroll = ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 12)
    scroll.add_child(content)
    status_label = text_label("原型 V0.0.2 · 四层世界基础", 15, MUTED)
    root.add_child(status_label)
    timer = Timer.new()
    timer.wait_time = 1.0
    timer.timeout.connect(func(): World.advance_days([1, 5, 30][speed_button.selected]))
    add_child(timer)

func toggle_play() -> void:
    if timer.is_stopped():
        timer.start()
        play_button.text = "暂停"
    else:
        pause_time()

func pause_time() -> void:
    timer.stop()
    play_button.text = "继续"

func show_tab(tab: String) -> void:
    active_tab = tab
    refresh()

func refresh() -> void:
    var state: Dictionary = World.state
    if state.is_empty():
        return
    var clan: Dictionary = state["clan"]
    date_label.text = World.date_text()
    resource_label.text = "公库 %d贯    储粮 %d石    族人 %d" % [int(clan["cash"]), int(clan["grain"]), state["characters"].size()]
    for tab in nav_buttons:
        nav_buttons[tab].set_pressed_no_signal(tab == active_tab)
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    match active_tab:
        "宗族总览": overview()
        "人物名册": roster()
        "房支与家庭": households()
        "家谱": genealogy()
        "财产账簿": property_book()
        "国家与地区": geography()

func heading(title: String, description: String) -> void:
    content.add_child(text_label(title, 28, GOLD))
    content.add_child(text_label(description, 16, MUTED))

func overview() -> void:
    var s: Dictionary = World.state
    var c: Dictionary = s["clan"]
    heading(str(c["name"]), str(c["location"]))
    var summary = panel(content)
    summary.add_child(text_label("现任族长  ·  " + World.person_name(int(c["leader_id"])), 22))
    summary.add_child(text_label("%d 名成员    %d 个房支    %d 户家庭" % [s["characters"].size(), s["branches"].size(), s["households"].size()], 20))
    var assets = panel(content)
    assets.add_child(text_label("公共财产", 20, GOLD))
    assets.add_child(text_label("族田 %d亩    公库 %d贯    储粮 %d石" % [int(c["land"]), int(c["cash"]), int(c["grain"])], 20))
    var note = panel(content)
    note.add_child(text_label("当前原型范围", 20, GOLD))
    note.add_child(text_label("时间推进、年龄变化、组织查询、财产统计、存读档。", 18))
    note.add_child(text_label("尚未模拟生产、死亡、婚姻、生育或继承；资产不会随时间变化。", 16, MUTED))

func roster() -> void:
    heading("人物名册", "点击人物查看六维能力、亲属及家庭归属")
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    content.add_child(row)
    var list = panel(row)
    list.add_child(text_label("族人及家庭成员", 19, GOLD))
    for p in World.state["characters"]:
        var item = button("%s  ·  %d岁  ·  %s" % [p["name"], World.age_of(p), World.branch_name(int(p["branch_id"]))], select_person.bind(int(p["id"])))
        item.alignment = HORIZONTAL_ALIGNMENT_LEFT
        list.add_child(item)
    var detail = panel(row)
    var selected: Dictionary = World.person_by_id(selected_id)
    if selected.is_empty() or int(selected.get("clan_id", -1)) != int(World.state["clan"]["id"]):
        if World.state["characters"].is_empty():
            return
        selected = World.state["characters"][0]
        selected_id = int(selected["id"])
    detail.add_child(text_label(str(selected["name"]), 28, GOLD))
    detail.add_child(text_label("%s · %d岁 · %s" % [selected["sex"], World.age_of(selected), selected["occupation"]]))
    detail.add_child(text_label("父：%s" % World.person_name(int(selected["father_id"]))))
    detail.add_child(text_label("母：%s" % World.person_name(int(selected["mother_id"]))))
    detail.add_child(text_label("配偶：%s" % World.person_name(int(selected["spouse_id"]))))
    detail.add_child(text_label("六维能力（测试数值）", 20, GOLD))
    for i in range(6):
        var r = HBoxContainer.new()
        detail.add_child(r)
        r.add_child(text_label(["军", "政", "商", "谋", "交", "学"][i], 18))
        var bar = ProgressBar.new()
        bar.max_value = 100
        bar.value = float(selected["skills"][i])
        bar.show_percentage = false
        bar.custom_minimum_size = Vector2(120, 20)
        bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        r.add_child(bar)
        r.add_child(text_label(str(int(selected["skills"][i])), 18))

func select_person(id: int) -> void:
    selected_id = id
    refresh()

func households() -> void:
    heading("房支与家庭", "家庭资产独立于宗族公产")
    for b in World.state["branches"]:
        var block = panel(content)
        block.add_child(text_label("%s  ·  主事：%s" % [b["name"], World.person_name(int(b["head_id"]))], 21, GOLD))
        for h in World.state["households"]:
            if int(h["branch_id"]) != int(b["id"]):
                continue
            var names: PackedStringArray = []
            for p in World.state["characters"]:
                if int(p["household_id"]) == int(h["id"]):
                    names.append(str(p["name"]))
            block.add_child(text_label("%s  |  %d人  |  田地%d亩" % [h["name"], names.size(), int(h["land"])]))
            block.add_child(text_label("、".join(names), 16, MUTED))

func genealogy() -> void:
    heading("家谱", "简化家谱：共同先祖、三房、各房后代；配偶在人物详情中查看")
    var ancestor = panel(content)
    for p in World.state["ancestors"]:
        ancestor.add_child(text_label(str(p["name"]), 24, GOLD))
    for b in World.state["branches"]:
        var group = panel(content)
        group.add_child(text_label("%s  /  %s" % [b["name"], World.person_name(int(b["head_id"]))], 22, GOLD))
        for p in World.state["characters"]:
            if int(p["branch_id"]) != int(b["id"]) or int(p["father_id"]) == -1:
                continue
            var depth: int = genealogy_depth(p)
            group.add_child(text_label("    ".repeat(depth - 1) + "└ " + str(p["name"]) + "  ·  父：" + World.person_name(int(p["father_id"])), 17))

func genealogy_depth(person: Dictionary) -> int:
    var depth: int = 0
    var visited: Dictionary = {}
    var current: Dictionary = person
    while not current.is_empty():
        var id := int(current["id"])
        if visited.has(id):
            break
        visited[id] = true
        current = World.person_by_id(int(current.get("father_id", -1)))
        if not current.is_empty():
            depth += 1
    return maxi(depth, 1)

func geography() -> void:
    heading("国家与地区", "政权、行政隶属与聚落独立记录")
    for polity in World.world_state["polities"]:
        var block = panel(content)
        block.add_child(text_label(str(polity["name"]), 22, GOLD))
    for region in World.world_state["regions"]:
        var block = panel(content)
        block.add_child(text_label(str(region["name"]), 20, GOLD))
        var parent = World.entity("regions", int(region["parent_id"]))
        var legal = World.entity("polities", int(region["legal_polity_id"]))
        var actual = World.entity("polities", int(region["controlling_polity_id"]))
        block.add_child(text_label("上级：%s  |  法定归属：%s  |  实际控制：%s" % [parent.get("name", "无"), legal.get("name", "无"), actual.get("name", "无")]))
        for settlement in World.world_state["settlements"]:
            if int(settlement["region_id"]) == int(region["id"]):
                block.add_child(text_label("聚落：" + str(settlement["name"]), 16, MUTED))

func property_book() -> void:
    heading("财产账簿", "公产与家庭财产分别统计；本版仅展示，不支持交易")
    var c: Dictionary = World.state["clan"]
    var public_box = panel(content)
    public_box.add_child(text_label("宗族公产", 21, GOLD))
    public_box.add_child(text_label("田地 %d亩  |  钱财 %d贯  |  粮食 %d石" % [int(c["land"]), int(c["cash"]), int(c["grain"])]))
    var land: int = 0
    var cash: int = 0
    var grain: int = 0
    var private_box = panel(content)
    private_box.add_child(text_label("家庭财产", 21, GOLD))
    for h in World.state["households"]:
        land += int(h["land"])
        cash += int(h["cash"])
        grain += int(h["grain"])
        private_box.add_child(text_label("%s  |  %d亩  |  %d贯  |  %d石" % [h["name"], int(h["land"]), int(h["cash"]), int(h["grain"])]))
    var total = panel(content)
    total.add_child(text_label("全族关联资产（不可全部调动）", 21, GOLD))
    total.add_child(text_label("田地 %d亩  |  钱财 %d贯  |  粮食 %d石" % [land + int(c["land"]), cash + int(c["cash"]), grain + int(c["grain"])]))

func save_current() -> void:
    var result: Error = World.save_game()
    status_label.text = "已保存到 user://clan_save.json" if result == OK else "保存失败：" + error_string(result)

func load_current() -> void:
    pause_time()
    var result: Error = World.load_game()
    status_label.text = "已读取存档" if result == OK else "读取失败：" + error_string(result)

func confirm_reset() -> void:
    pause_time()
    var dialog = ConfirmationDialog.new()
    dialog.title = "重新开始"
    dialog.dialog_text = "重置当前世界？已有存档不会被删除。"
    dialog.confirmed.connect(func():
        selected_id = 1
        active_tab = "宗族总览"
        World.new_game()
        status_label.text = "已建立新世界"
    )
    dialog.confirmed.connect(dialog.queue_free)
    dialog.canceled.connect(dialog.queue_free)
    add_child(dialog)
    dialog.popup_centered(Vector2i(420, 140))
