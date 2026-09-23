(function () {
    const LEGACY_TAB = { balance: "numbers", localization: "check" };
    const TITLES = {
        home: "Trinity",
        analytics: "Trinity Analytics",
        players: "Trinity Игроки",
        abilities: "Trinity Способности",
        stickers: "Trinity Stickers",
    };

    const params = new URLSearchParams(location.search);
    const rawView = params.get("view");
    let view = rawView;
    let tab = params.get("tab");

    if (LEGACY_TAB[rawView]) {
        tab = LEGACY_TAB[rawView];
        view = "abilities";
        params.set("view", "abilities");
        params.set("tab", tab);
        history.replaceState(null, "", `/?${params.toString()}`);
    }

    if (view !== "analytics" && view !== "players" && view !== "abilities" && view !== "stickers") {
        view = "home";
    }
    if (tab !== "numbers" && tab !== "check") {
        tab = "texts";
    }

    document.documentElement.dataset.view = view;
    document.documentElement.dataset.tab = tab;
    document.title = TITLES[view];

    document.querySelectorAll(".rail-item").forEach((item) => {
        if (item.dataset.nav === view) {
            item.setAttribute("aria-current", "page");
        } else {
            item.removeAttribute("aria-current");
        }
    });

    const stack = document.getElementById("toast-stack");
    let dirty = false;

    function toast(text, kind) {
        if (!text || !stack) {
            return;
        }
        const node = document.createElement("div");
        node.className = "toast" + (kind === true || kind === "ok" ? " ok" : kind === false || kind === "err" ? " err" : "");
        const body = document.createElement("span");
        body.className = "toast-text";
        body.textContent = text;
        const close = document.createElement("button");
        close.type = "button";
        close.className = "toast-close";
        close.setAttribute("aria-label", "Закрыть");
        close.textContent = "×";
        close.addEventListener("click", () => node.remove());
        node.append(body, close);
        stack.appendChild(node);
        const failed = kind === false || kind === "err";
        if (!failed) {
            setTimeout(() => node.remove(), 4000);
        }
    }

    function setLoading(on) {
        document.documentElement.classList.toggle("is-loading", on === true);
    }

    function setDirty(on) {
        dirty = on === true;
        document.querySelectorAll(".dirty-flag").forEach((flag) => {
            flag.classList.toggle("hidden", !dirty);
        });
    }

    function skeleton(node, className, count) {
        if (!node) {
            return;
        }
        node.innerHTML = "";
        for (let i = 0; i < count; i++) {
            const item = document.createElement("div");
            item.className = `skel ${className}`;
            node.appendChild(item);
        }
    }

    window.Trinity = { view, tab, toast, setLoading, setDirty, skeleton };

    window.addEventListener("beforeunload", (event) => {
        if (!dirty) {
            return;
        }
        event.preventDefault();
        event.returnValue = "";
    });

    function typing(node) {
        if (!node) {
            return false;
        }
        return node.isContentEditable || /^(input|textarea|select)$/i.test(node.tagName);
    }

    function visibleForm() {
        const forms = Array.from(document.querySelectorAll("form"));
        return forms.find((form) => form.offsetParent !== null) || null;
    }

    document.addEventListener("keydown", (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s") {
            const form = visibleForm();
            if (!form) {
                return;
            }
            event.preventDefault();
            if (typeof form.requestSubmit === "function") {
                form.requestSubmit();
            } else {
                form.dispatchEvent(new Event("submit", { cancelable: true, bubbles: true }));
            }
            return;
        }
        if (event.ctrlKey || event.metaKey || event.altKey || typing(document.activeElement)) {
            return;
        }
        const target = document.querySelector(`.rail-item[data-hotkey="${event.key}"]`);
        if (target) {
            event.preventDefault();
            location.assign(target.getAttribute("href"));
        }
    });

    function loadApp(src) {
        const app = document.createElement("script");
        app.src = src;
        document.body.appendChild(app);
    }

    if (view === "home") {
        loadApp("/app/home.js");
        return;
    }
    if (view === "analytics") {
        loadApp("/app/analytics.js");
        return;
    }
    if (view === "players") {
        loadApp("/app/players.js");
        return;
    }
    if (view === "abilities") {
        loadApp("/app/abilities.js");
        return;
    }

    const lottie = document.createElement("script");
    lottie.src = "https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js";
    lottie.onload = function () {
        loadApp("/app/stickers.js");
    };
    lottie.onerror = function () {
        loadApp("/app/stickers.js");
    };
    document.body.appendChild(lottie);
})();
