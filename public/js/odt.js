$(document).ready(function() {
  $('.player').each(function () {
    jwplayer($(this).attr('id')).setup({
      flashplayer: "/media/player.swf", 
      file: $(this).attr('href'), 
      height: 270, 
      width: 480
    });
  });
});
