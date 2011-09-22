$(document).ready(function(){
  $("#gallery_4dd5a4f6fb60b54efe00001b").sudoSlider({
    controlsShow: true,
    controlsFade: true,
    prevHtml: '<a href="#" class="prevBtn" alt="previous" title="previous"> prev </a>',
    nextHtml: '<a href="#" class="nextBtn" alt="next" title="next"> next </a>',
    numeric: false,
    preloadAjax: true,
    auto: true,
    fade:true,
    pause:4200,
                
    afterAniFunc: function(t){
      var gallery_link = $(this).find('a').attr("href");
      if (gallery_link == undefined) {
        $('#gallery_link').attr("href", "#");
      } else {
        $('#gallery_link').attr("href", gallery_link);
      }
    }
  });
});


