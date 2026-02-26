const CONTEXT = $.GetContextPanel()
const SLIDES_CONTAINER = $("#SlidesContainer")
const SLIDES_DATA = {
    [1]: {
        hero: "npc_dota_hero_omniknight",
        title: "ui.custom_loading_screen.slide_1.title",
        contents: [
            "ui.custom_loading_screen.slide_1.content",
        ],
    },
    [2]: {
        hero: "npc_dota_hero_ogre_magi",
        title: "ui.custom_loading_screen.slide_2.title",
        contents: [
            "ui.custom_loading_screen.slide_2.content",
        ],
        image_class: "ImageTelegramQR_220",
    },
    [3]: {
        hero: "npc_dota_hero_doom_bringer",
        title: "ui.custom_loading_screen.slide_3.title",
        contents: [
            "ui.custom_loading_screen.slide_3.content",
        ],
    },
    [4]: {
        hero: "npc_dota_hero_phantom_assassin",
        title: "ui.custom_loading_screen.slide_4.title",
        contents: [
            "ui.custom_loading_screen.slide_4.content",
        ],
    },
}

let CURRENT_SLIDE_INDEX = 0

function InitSlides(){
    SLIDES_CONTAINER.RemoveAndDeleteChildren()

    for(const [index, slide_data] of Object.entries(SLIDES_DATA)) {
        const slide_panel = $.CreatePanel("Panel", SLIDES_CONTAINER, "Slide_" + index, {})

        slide_panel.BLoadLayoutSnippet("Slide")

        if(slide_data.hero){
            slide_panel.FindChildTraverse("HeroPanel").SetUnit(slide_data.hero, "", false)
        }

        if(slide_data.title){
            slide_panel.FindChildTraverse("Title").text = $.Localize("#" + slide_data.title)
        }
        
        if(slide_data.contents){
            for(const token of slide_data.contents){
                const text_panel = $.CreatePanel("Label", slide_panel.FindChildTraverse("ContentContainer"), "", { text: $.Localize("#" + token), html: true})
            }
        }

        if(slide_data.image_class){
            slide_panel.FindChildTraverse("InfoImage").visible = true
            slide_panel.FindChildTraverse("InfoImage").AddClass(slide_data.image_class)
        } else {
            slide_panel.FindChildTraverse("InfoImage").visible = false
        }
    }
}

function SwapSlide(increment){
    const slide_panels = SLIDES_CONTAINER.Children()

    if (slide_panels.length === 0) return

    let next_index = CURRENT_SLIDE_INDEX + increment

    const max_index = slide_panels.length - 1

    if (next_index > max_index) {
        next_index = 0
    } else if (next_index < 0) {
        next_index = max_index
    }

    SetSlide(next_index)
}

function SetSlide(index){
    const slide_panels = SLIDES_CONTAINER.Children()

    if (slide_panels.length === 0 || index >= slide_panels.length) return

    for(const slide_panel of slide_panels){
        slide_panel.visible = false
    }

    slide_panels[index].visible = true
    CURRENT_SLIDE_INDEX = index
}

InitSlides()
SetSlide(0)