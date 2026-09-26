GameUI.CustomUIConfig().team_select = {
  bShowSpectatorTeam: true,
};

(function () {
  var config = GameUI.CustomUIConfig();
  if (config.trinityHttpRelay) {
    return;
  }
  config.trinityHttpRelay = true;

  var incoming = {};

  function SendResponse(id, status, body) {
    body = body == null ? "" : String(body);
    var size = 180;
    var total = Math.max(1, Math.ceil(body.length / size));
    for (var seq = 0; seq < total; seq++) {
      GameEvents.SendCustomGameEventToServer("trinity_http_res", {
        id: id,
        seq: seq,
        total: total,
        status: status,
        part: body.substring(seq * size, seq * size + size),
      });
    }
  }

  function RunRequest(packet, id) {
    if (!packet || !packet.url || typeof $.AsyncWebRequest !== "function") {
      SendResponse(id, 0, "");
      return;
    }

    var options = {
      type: packet.method || "GET",
      timeout: packet.timeout || 5000,
      headers: {
        Accept: "application/json",
      },
    };

    if (packet.headers) {
      for (var name in packet.headers) {
        if (packet.headers.hasOwnProperty(name) && packet.headers[name]) {
          options.headers[name] = String(packet.headers[name]);
        }
      }
    }

    options.success = function (data) {
      var text = typeof data === "string" ? data : JSON.stringify(data || {});
      SendResponse(id, 200, text);
    };
    options.error = function (data) {
      var status = 0;
      if (data && (data.status || data.statusCode)) {
        status = Number(data.status || data.statusCode) || 0;
      }
      SendResponse(id, status, "");
    };

    if (packet.body) {
      options.data = { body: packet.body };
    }

    $.AsyncWebRequest(packet.url, options);
  }

  GameEvents.Subscribe("trinity_http_req", function (event) {
    if (!event) {
      return;
    }
    var id = Number(event.id);
    var total = Number(event.total) || 0;
    var seq = Number(event.seq) || 0;
    if (!id || total < 1 || seq < 0 || seq >= total) {
      return;
    }

    var bag = incoming[id];
    if (!bag) {
      bag = { parts: [], got: 0, total: total };
      incoming[id] = bag;
    }
    if (bag.parts[seq] == null) {
      bag.parts[seq] = String(event.part || "");
      bag.got++;
    }
    if (bag.got < bag.total) {
      return;
    }

    var text = "";
    for (var index = 0; index < bag.total; index++) {
      text += bag.parts[index] || "";
    }
    delete incoming[id];

    var packet = null;
    try {
      packet = JSON.parse(text);
    } catch (error) {
      SendResponse(id, 0, "");
      return;
    }
    RunRequest(packet, id);
  });
})();
