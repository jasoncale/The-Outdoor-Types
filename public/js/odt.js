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
        width: 250,
        dock: false,
        controlbar: "bottom",
        "playlist.position" : "none",
        backcolor: "ffffff",
        frontcolor: "333333",
        wmode: "transparent"
      }).onPlay(function () {
        var currentId = this.id;
        $(tracks).each(function () {
          if (this.id != currentId && this.getState() == "PLAYING") {
            this.pause();
          };
        });
      });
      tracks.push(player);
    }
  });
  
  $('.toggle-track').click(function () {
    jwplayer($(this).attr('data-track')).play();
    return false;
  })
  
});
