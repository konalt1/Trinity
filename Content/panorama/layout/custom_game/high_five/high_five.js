const SecondAbilities = {
  high_five: {
    id: "HighFiveAbility",
    abilityName: "high_five_custom",
    image: "s2r://panorama/images/spellicons/consumables/plus_high_five_png.vtex",
  },
};

class SecondaryAbilities {
  constructor() {
    dotaHud.FindChildrenWithClassTraverse("SA_RemoveOnReload").forEach((i) => i.DeleteAsync(0));

    this.context = $.GetContextPanel();
    this.buffContainer = FindDotaHudElement("BuffContainer");
    this.abilityContainer = this.CreateContainer();

    this.playerId = Players.GetLocalPlayer();
    this.heroIndex = Game.GetPlayerInfo(this.playerId).player_selected_hero_entity_index;

    this.buttons = this.CreateButtons();

    this.SetBuffs();
    this.Tick();
  }

  CreateContainer() {
    const centerBlock = FindDotaHudElement("center_block");
    if (!centerBlock) throw "Cannot find center_block in DotaHud";

    const old_panel = centerBlock.FindChildTraverse("SecondAbilitiesContainer");
    if (old_panel) old_panel.DeleteAsync(0);

    const panel = $.CreatePanel("Panel", this.context, "SecondAbilitiesContainer", {
      class: "HideSecondAbilities",
    });
    panel.SetParent(centerBlock);

    return panel;
  }

  CreateButtons() {
    return Object.entries(SecondAbilities).reduce((obj, [name, values]) => {
      obj[name] = this.CreateButton(values);
      return obj;
    }, {});
  }

  CreateButton(values) {
    const button = $.CreatePanel("Panel", this.context, values.id, {
      class: "SecondAbility SA_RemoveOnReload",
    });
    button.BLoadLayoutSnippet("SecondAbilitySnippet");
    button.style.opacityMask = `url(${values.image})`;
    button.FindChildTraverse("SecondAbilityImage").SetImage(values.image);

    button.cooldownRoot = button.FindChildTraverse("CooldownContainer");
    button.background = button.FindChildTraverse("CooldownBackground_");
    button.label = button.FindChildTraverse("CooldownLabel");
    button.abilityName = values.abilityName;

    button.SetPanelEvent("onactivate", () => this.PressAbility(values.abilityName));
    button.SetPanelEvent("onmouseover", () =>
      $.DispatchEvent("DOTAShowAbilityTooltipForEntityIndex", button, values.abilityName, Players.GetLocalPlayerPortraitUnit())
    );
    button.SetPanelEvent("onmouseout", () => $.DispatchEvent("DOTAHideAbilityTooltip", button));

    button.SetParent(this.abilityContainer);

    return button;
  }

  SetBuffs() {
    const abilities = FindDotaHudElement("abilities");
    if (!abilities) return;

    const can_upgrade = abilities.FindChildrenWithClassTraverse("show_level_up_tab").length > 0;
    const margin = can_upgrade ? "15px" : "46px";

    this.buffContainer.style.marginBottom = margin;
  }

  PressAbility(abilityName) {
    const selected_index = Players.GetLocalPlayerPortraitUnit();
    if (this.heroIndex === -1) this.heroIndex = Game.GetPlayerInfo(this.playerId).player_selected_hero_entity_index;
    if (this.heroIndex != selected_index) return;

    const ability = Entities.GetAbilityByName(this.heroIndex, abilityName);
    if (ability) Abilities.ExecuteAbility(ability, this.heroIndex, false);
  }

  Tick() {
    if (Object.keys(this.buttons).length <= 0) return;

    const selected_index = Players.GetLocalPlayerPortraitUnit();

    this.abilityContainer.SetHasClass("ShowSecondAbilities", Entities.IsHero(selected_index));

    Object.values(this.buttons).forEach((button) => {
      if (!button) return;

      const ability = Entities.GetAbilityByName(selected_index, button.abilityName);

      if (!Abilities.IsCooldownReady(ability) && !Entities.IsEnemy(selected_index)) {
        const cooldown = Abilities.GetCooldownTimeRemaining(ability);
        const cooldown_max = Abilities.GetCooldownLength(ability);
        const progress = (cooldown / cooldown_max) * -360;

        button.cooldownRoot.visible = true;
        button.background.style.clip = `radial(50% 75%, 0deg, ${progress}deg)`;
        button.label.text = String(Math.ceil(cooldown));
      } else button.cooldownRoot.visible = false;
    });

    this.SetBuffs();

    $.Schedule(0.03, () => this.Tick());
  }
}

const second_ability = new SecondaryAbilities();
