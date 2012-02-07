$(document).ready(function() {
	// Top nav fixed position
	var top_nav_position = $(".top_nav").offset();
	var top_nav_position_top = top_nav_position.top;
	$(window).scroll(function(){
		var y = $(window).scrollTop();
		if( y > top_nav_position_top ){
			$(".top_nav").addClass("fixed");
		} else {
			$(".top_nav").removeClass("fixed");
		}
	});
	// Placeholder for input fields
	function placeholder(){
        $("input[type=text]").each(function(){  
            var phvalue = $(this).attr("placeholder");  
            $(this).val(phvalue);  
        });  
    }  
    placeholder();  
    $("input[type=text]").focusin(function(){  
        var phvalue = $(this).attr("placeholder");  
        if (phvalue == $(this).val()) {  
        $(this).val("");  
        }  
    });  
    $("input[type=text]").focusout(function(){  
        var phvalue = $(this).attr("placeholder");  
        if ($(this).val() == "") {  
            $(this).val(phvalue);  
        }  
    }); 
});