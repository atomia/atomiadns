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
	
	//Code highliter
	$("pre").each(function(){
		var olClass = $(this).hasClass("unnumbered") ? ' class="unnumbered"' : '';
		var x = $(this).html();
		// Find string inside quoutes and wrap with span
		x = x.replace(/"(.*?)"/gm, "\"<span>$1</span>\"");
		x = x.replace(/'(.*?)'/gm, "\'<span>$1</span>\'");
		// Trim white space
		x = x.replace(/^\s+|\s+$/gm, '');
		// Find double \n and replace with one
		x = x.replace(/\n\n/gm, "\n");
		//Wrap each new line with LI
		x = x.replace(/\n/gm, "</li><li>");
		//Return wrapped.
		$(this).html("<ol" + olClass + "><li>" + x + "</li></ol>");
	});
});
