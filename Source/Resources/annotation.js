//
//  bridge.js
//  FolioReaderKit
//
//  Created by Renato Lovizotto on 19/01/17.
//

function addMarkers(gap) {
    var markersToRemove = document.getElementsByClassName('marker-annotation');
    for (var j = 0; j < markersToRemove.length; j++) {
        markersToRemove[j].parentNode.removeChild(markersToRemove[j]);
    }
    
    var DEFAULT_GAP = 10;
    var BTN_TYPE_DISCUSSION = 'url(' + discussionSvg + ')';
    
    var annotations = document.getElementsByTagName('marker');
    var gap = gap == undefined ? DEFAULT_GAP : gap;
    
    var height = 30;
    var lastPosition = 0;
    var totalAnnotations = annotations.length
    for (var i = 0; i < totalAnnotations; i++) {
        
        // Id Attribute
        var id = annotations[i].getAttribute('id');
        var type = annotations[i].dataset.type;
        
        var show = annotations[i].dataset.show;
        
        if(show == "false"){
            continue
        }
        
        // Create Marker
        var markerAnnotation = document.createElement('span');
        markerAnnotation.className = 'marker-annotation';
        
        if (type === "discussion") {
            markerAnnotation.style.backgroundImage = BTN_TYPE_DISCUSSION;
        }
        
        markerAnnotation.setAttribute('id', id);
        markerAnnotation.setAttribute('data-type', type);
        markerAnnotation.onclick = function () {
            var schema = this.dataset.type == "discussion" ? "discussion://" : "annotation://";
            var id = this.id.substr(0, this.id.length - 2);
            
            console.log(this.id);
            console.log("Id length " + this.id.length);
            
            window.location = schema + id;
        }
        
        var position = annotations[i].offsetTop - 5;
        
        if (position == lastPosition) {
            position += height + gap;
        }
        
        if (position <= (lastPosition + height + gap)){
            position = lastPosition + height + gap;
        }
        
        markerAnnotation.style.top = position + "px";
        
        // Insert Element on Body
        document.body.appendChild(markerAnnotation);
        
        lastPosition = position;
    }
}

var t = setInterval(function() {
    if (document.readyState == 'complete') {
        console.log("a");
        var timer = setTimeout(function() {
           console.log("b");
           addMarkers(15);
        },100);
        clearInterval(t);
    }
},1);

// Exemplo com refresh
window.onresize = function() {
    addMarkers(15);
}
