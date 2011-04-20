var tracks = [];
$(document).ready(function() {
  $('.track').each(function () {
    if ($(this).attr('href')) {
      var player = jwplayer($(this).attr('id')).setup({
        playlist: "none",
        flashplayer: "/media/player.swf", 
        duration: parseInt($(this).attr('data-duration')),
        file: $(this).attr('href'),
        provider: "sound",
        height: 24,
        dock: false,
        controlbar: "bottom",
        "playlist.position" : "none",
        backcolor: "000000",
        frontcolor: "EEEEEE"
      }).onPlay(function () {
        var currentId = this.id;
        $(tracks).each(function () {
          if (this.id != currentId && this.getState() == "PLAYING") {
            console.log("pausing");
            this.pause();
          };
        });
      });
      tracks.push(player);
    }
  });
});
