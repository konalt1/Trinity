const PANEL_TITLE = $("#GameEventTitle")

GameEvents.Subscribe("draw_game_event", ({ 
    color = "white", 
    duration = 3, 
    sound_event = "_game_events.template_sound_event",
    text_token = "TEMPLATE TITLE TEXT", 
}) => {
    PANEL_TITLE.AddClass("IsDraw");
    PANEL_TITLE.text = $.Localize(text_token);
    PANEL_TITLE.style.washColor = color;

    $.Schedule(duration, () => PANEL_TITLE.RemoveClass("IsDraw"));
    Game.EmitSound(sound_event);
});
  
// TEST 
$.Schedule(3, function(){ 
    GameEvents.SendEventClientSide("draw_game_event", {text_token: "Roshan zaspawnilsya : )", duration: 3, color: "#aa39aa"})
})  