//
//  bridge.js
//  FolioReaderKit
//
//  Created by Heberti Almeida on 06/05/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

var thisHighlight;
var audioMarkClass;
var wordsPerMinute = 180;
var markInstance = null;
var searchResults = 0;
var currentResultIndex = 0;
var currentClass = "current";
var offsetTop = 50;

// prev button
var prevBtn = $("button[data-search='prev']");

// next button
var nextBtn = $("button[data-search='next']");

document.addEventListener("DOMContentLoaded", function(event) {
    markInstance = new Mark(document.querySelector("body"));
});

function performMark(keyword) {
    markInstance.unmark({
        done: function() {
            markInstance.mark(keyword, {"debug": true});
            searchResults = $("body").find("mark");
            currentResult = 0;
            jumpTo();
        }
    });
}

function clearMarks() {
    markInstance.unmark();
}

/**
 * Jumps to the element matching the currentIndex
 */
function jumpTo() {
    if (searchResults.length) {
        var position, current = searchResults.eq(currentResultIndex);
        searchResults.removeClass(currentClass);
        if (current.length) {
            current.addClass(currentClass);
            position = current.offset().top - offsetTop;
            window.scrollTo(0, position - 150);
        }
    }
    
    window.location = "search-jumped://" + (currentResultIndex + 1) + "," + searchResults.length;
}

/**
 * Next and previous search jump to
 */
nextBtn.add(prevBtn).on("click", function() {
    if (searchResults.length) {
        currentResultIndex += $(this).is(prevBtn) ? -1 : 1;
        if (currentResultIndex < 0) {
            currentResultIndex = searchResults.length - 1;
        }
        if (currentResultIndex > searchResults.length - 1) {
            currentResultIndex = 0;
        }
        jumpTo();
    }
});

function skipToPreviousMark() {
    if (searchResults.length) {
        currentResultIndex -= 1;
        if (currentResultIndex < 0) {
            currentResultIndex = searchResults.length - 1;
        }
        if (currentResultIndex > searchResults.length - 1) {
            currentResultIndex = 0;
        }
        jumpTo();
    }
}

function skipToNextMark() {
    if (searchResults.length) {
        currentResultIndex += 1;
        if (currentResultIndex < 0) {
            currentResultIndex = searchResults.length - 1;
        }
        if (currentResultIndex > searchResults.length - 1) {
            currentResultIndex = 0;
        }
        jumpTo();
    }
}

// Generate a GUID
function guid() {
    function s4() {
        return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
    }
    var guid = s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4();
    return guid.toUpperCase();
}

// Get All HTML
function getHTML() {
    return document.documentElement.outerHTML;
}

// Class manipulation
function hasClass(ele,cls) {
  return !!ele.className.match(new RegExp('(\\s|^)'+cls+'(\\s|$)'));
}

function addClass(ele,cls) {
  if (!hasClass(ele,cls)) ele.className += " "+cls;
}

function removeClass(ele,cls) {
  if (hasClass(ele,cls)) {
    var reg = new RegExp('(\\s|^)'+cls+'(\\s|$)');
    ele.className=ele.className.replace(reg,' ');
  }
}

// Font name class
function setFontName(cls) {
    var elm = document.documentElement;
    removeClass(elm, "andada");
    removeClass(elm, "lato");
    removeClass(elm, "lora");
    removeClass(elm, "raleway");
    addClass(elm, cls);
}

// Toggle night mode
function nightMode(enable) {
    var elm = document.documentElement;
    if(enable) {
        addClass(elm, "nightMode");
    } else {
        removeClass(elm, "nightMode");
    }
}

// Set font size
function setFontSize(cls) {
    var elm = document.documentElement;
    removeClass(elm, "textSizeOne");
    removeClass(elm, "textSizeTwo");
    removeClass(elm, "textSizeThree");
    removeClass(elm, "textSizeFour");
    removeClass(elm, "textSizeFive");
    addClass(elm, cls);
    
    window.location = "font-changed://{" + cls + "}";
}

// Set text alignment
function setTextAlignment(style) {
    var html = document.getElementsByTagName("html")[0]
    html.style.textAlign = style
}


// http://stackoverflow.com/questions/4811822/get-a-ranges-start-and-end-offsets-relative-to-its-parent-container

function createAnnotation() {
    var selection = window.getSelection();
    var range = selection.getRangeAt(0);
    var additionalRange = 30
    
    var selectedText = selection.toString();
    var selectedOffset = selection.focusOffset;
    var fullText = selection.focusNode.textContent;
    
    var pre = fullText.substr(0, selectedOffset - selectedText.length);
    var post = fullText.substr(selectedOffset, fullText.length);
    
    console.log("Texto selecionado: \"" + selectedText + "\"");
    console.log("Texto completo: \"" + fullText + "\"");
    console.log("Pré anotação: \"" + pre + "\"");
    console.log("Pós anotação: \"" + post + "\"");
    
    var params = [];
    params.push({content: selectedText, contentPre: pre, contentPost: post});
    
    return JSON.stringify(params);
}

/*
 *	Native bridge Highlight text
 */
function highlightString(style) {
    var range = window.getSelection().getRangeAt(0);
    var startOffset = range.startOffset;
    var endOffset = range.endOffset;
    var selectionContents = range.extractContents();
    var elm = document.createElement("highlight");
    var id = guid();
    
    elm.appendChild(selectionContents);
    elm.setAttribute("id", id);
    elm.setAttribute("onclick","callHighlightURL(this);");
    elm.setAttribute("class", style);
    
    range.insertNode(elm);
    thisHighlight = elm;
    
    var params = [];
    params.push({id: id, rect: getRectForSelectedText(elm), startOffset: startOffset.toString(), endOffset: endOffset.toString()});
    
    return JSON.stringify(params);
}

// Menu colors
function setHighlightStyle(style) {
    thisHighlight.className = style;
    return thisHighlight.id;
}

function removeThisHighlight() {
    thisHighlight.outerHTML = thisHighlight.innerHTML;
    return thisHighlight.id;
}

function removeHighlightById(elmId) {
    var elm = document.getElementById(elmId);
    elm.outerHTML = elm.innerHTML;
    return elm.id;
}

function getThisHighlight() {
    return JSON.stringify(thisHighlight);
}

function getHighlightContent() {
    return thisHighlight.textContent;
}

function getBodyText() {
    return document.body.innerText;
}

// Method that returns only selected text plain
var getSelectedText = function() {
    return window.getSelection().toString();
}

// Method that gets the Rect of current selected text
// and returns in a JSON format
var getRectForSelectedText = function(elm) {
    if (typeof elm === "undefined") elm = window.getSelection().getRangeAt(0);
    
    var rect = elm.getBoundingClientRect();
    return "{{" + rect.left + "," + rect.top + "}, {" + rect.width + "," + rect.height + "}}";
}

// Method that call that a hightlight was clicked
// with URL scheme and rect informations
var callHighlightURL = function(elm) {
    var URLBase = "highlight://";
    var currentHighlightRect = getRectForSelectedText(elm);
    thisHighlight = elm;
    
    window.location = URLBase + "{" + thisHighlight.getAttribute("id") + "}," + encodeURIComponent(currentHighlightRect);
}


// Reading time
function getReadingTime() {
    var text = document.body.innerText;
    var totalWords = text.trim().split(/\s+/g).length;
    var wordsPerSecond = wordsPerMinute / 60; //define words per second based on words per minute
    var totalReadingTimeSeconds = totalWords / wordsPerSecond; //define total reading time in seconds
    var readingTimeMinutes = Math.round(totalReadingTimeSeconds / 60);

    return readingTimeMinutes;
}

/**
 Get Vertical or Horizontal paged #anchor offset
 */
var getAnchorOffset = function(target, horizontal) {
    var elem = document.getElementById(target);
    
    if (!elem) {
        elem = document.getElementsByName(target)[0];
    }
    
    if (horizontal) {
        return document.body.clientWidth * Math.floor(elem.offsetTop / window.innerHeight);
    }
    
    return elem.offsetTop;
}

function findElementWithID(node) {
    if( !node || node.tagName == "BODY")
        return null
    else if( node.id )
        return node
    else
        return findElementWithID(node)
}

function findElementWithIDInView() {

    if(audioMarkClass) {
        // attempt to find an existing "audio mark"
        var el = document.querySelector("."+audioMarkClass)

        // if that existing audio mark exists and is in view, use it
        if( el && el.offsetTop > document.body.scrollTop && el.offsetTop < (window.innerHeight + document.body.scrollTop))
            return el
    }

    // @NOTE: is `span` too limiting?
    var els = document.querySelectorAll("span[id]")

    for(indx in els) {
        var element = els[indx];

        // Horizontal scroll
        if (document.body.scrollTop == 0) {
            var elLeft = document.body.clientWidth * Math.floor(element.offsetTop / window.innerHeight);
            // document.body.scrollLeft = elLeft;

            if (elLeft == document.body.scrollLeft) {
                return element;
            }

        // Vertical
        } else if(element.offsetTop > document.body.scrollTop) {
            return element;
        }
    }

    return null
}


/**
 Play Audio - called by native UIMenuController when a user selects a bit of text and presses "play"
 */
function playAudio() {
    var sel = getSelection();
    var node = null;

    // user selected text? start playing from the selected node
    if (sel.toString() != "") {
        node = sel.anchorNode ? findElementWithID(sel.anchorNode.parentNode) : null;

    // find the first ID'd element that is within view (it will
    } else {
        node = findElementWithIDInView()
    }

    playAudioFragmentID(node ? node.id : null)
}


/**
 Play Audio Fragment ID - tells page controller to begin playing audio from the following ID
 */
function playAudioFragmentID(fragmentID) {
    var URLBase = "play-audio://";
    window.location = URLBase + (fragmentID?encodeURIComponent(fragmentID):"")
}

/**
 Go To Element - scrolls the webview to the requested element
 */
function goToEl(el) {
    var top = document.body.scrollTop;
    var elTop = el.offsetTop - 20;
    var bottom = window.innerHeight + document.body.scrollTop;
    var elBottom = el.offsetHeight + el.offsetTop + 60

    if(elBottom > bottom || elTop < top) {
        document.body.scrollTop = el.offsetTop - 20
    }
    
    /* Set scroll left in case horz scroll is activated.
    
        The following works because el.offsetTop accounts for each page turned
        as if the document was scrolling vertical. We then divide by the window
        height to figure out what page the element should appear on and set scroll left
        to scroll to that page.
    */
    if( document.body.scrollTop == 0 ){
        var elLeft = document.body.clientWidth * Math.floor(el.offsetTop / window.innerHeight);
        document.body.scrollLeft = elLeft;
    }

    return el;
}

/**
 Remove All Classes - removes the given class from all elements in the DOM
 */
function removeAllClasses(className) {
    var els = document.body.getElementsByClassName(className)
    if( els.length > 0 )
    for( i = 0; i <= els.length; i++) {
        els[i].classList.remove(className);
    }
}

/**
 Audio Mark ID - marks an element with an ID with the given class and scrolls to it
 */
function audioMarkID(className, id) {
    if (audioMarkClass)
        removeAllClasses(audioMarkClass);

    audioMarkClass = className
    var el = document.getElementById(id);

    goToEl(el);
    el.classList.add(className)
}

function setMediaOverlayStyle(style){
    document.documentElement.classList.remove("mediaOverlayStyle0", "mediaOverlayStyle1", "mediaOverlayStyle2")
    document.documentElement.classList.add(style)
}

function setMediaOverlayStyleColors(color, colorHighlight) {
    var stylesheet = document.styleSheets[document.styleSheets.length-1];
    stylesheet.insertRule(".mediaOverlayStyle0 span.epub-media-overlay-playing { background: "+colorHighlight+" !important }")
    stylesheet.insertRule(".mediaOverlayStyle1 span.epub-media-overlay-playing { border-color: "+color+" !important }")
    stylesheet.insertRule(".mediaOverlayStyle2 span.epub-media-overlay-playing { color: "+color+" !important }")
}

var currentIndex = -1;


function findSentenceWithIDInView(els) {
    // @NOTE: is `span` too limiting?
    for(indx in els) {
        var element = els[indx];

        // Horizontal scroll
        if (document.body.scrollTop == 0) {
            var elLeft = document.body.clientWidth * Math.floor(element.offsetTop / window.innerHeight);
            // document.body.scrollLeft = elLeft;

            if (elLeft == document.body.scrollLeft) {
                currentIndex = indx;
                return element;
            }

        // Vertical
        } else if(element.offsetTop > document.body.scrollTop) {
            currentIndex = indx;
            return element;
        }
    }
    
    return null
}

function findNextSentenceInArray(els) {
    if(currentIndex >= 0) {
        currentIndex ++;
        return els[currentIndex];
    }
    
    return null
}

function resetCurrentSentenceIndex() {
    currentIndex = -1;
}

function getSentenceWithIndex(className) {
    var sentence;
    var sel = getSelection();
    var node = null;
    var elements = document.querySelectorAll("span.sentence");

    // Check for a selected text, if found start reading from it
    if (sel.toString() != "") {
        console.log(sel.anchorNode.parentNode);
        node = sel.anchorNode.parentNode;

        if (node.className == "sentence") {
            sentence = node

            for(var i = 0, len = elements.length; i < len; i++) {
                if (elements[i] === sentence) {
                    currentIndex = i;
                    break;
                }
            }
        } else {
            sentence = findSentenceWithIDInView(elements);
        }
    } else if (currentIndex < 0) {
        sentence = findSentenceWithIDInView(elements);
    } else {
        sentence = findNextSentenceInArray(elements);
    }

    var text = sentence.innerText || sentence.textContent;
    
    goToEl(sentence);
    
    if (audioMarkClass){
        removeAllClasses(audioMarkClass);
    }
    
    audioMarkClass = className;
    sentence.classList.add(className)
    return text;
}

function wrappingSentencesWithinPTags(){
    currentIndex = -1;
    "use strict";
    
    var rxOpen = new RegExp("<[^\\/].+?>"),
    rxClose = new RegExp("<\\/.+?>"),
    rxSupStart = new RegExp("^<sup\\b[^>]*>"),
    rxSupEnd = new RegExp("<\/sup>"),
    sentenceEnd = [],
    rxIndex;
    
    sentenceEnd.push(new RegExp("[^\\d][\\.!\\?]+"));
    sentenceEnd.push(new RegExp("(?=([^\\\"]*\\\"[^\\\"]*\\\")*[^\\\"]*?$)"));
    sentenceEnd.push(new RegExp("(?![^\\(]*?\\))"));
    sentenceEnd.push(new RegExp("(?![^\\[]*?\\])"));
    sentenceEnd.push(new RegExp("(?![^\\{]*?\\})"));
    sentenceEnd.push(new RegExp("(?![^\\|]*?\\|)"));
    sentenceEnd.push(new RegExp("(?![^\\\\]*?\\\\)"));
    //sentenceEnd.push(new RegExp("(?![^\\/.]*\\/)")); // all could be a problem, but this one is problematic
    
    rxIndex = new RegExp(sentenceEnd.reduce(function (previousValue, currentValue) {
                                            return previousValue + currentValue.source;
                                            }, ""));
    
    function indexSentenceEnd(html) {
        var index = html.search(rxIndex);
        
        if (index !== -1) {
            index += html.match(rxIndex)[0].length - 1;
        }
        
        return index;
    }

    function pushSpan(array, className, string, classNameOpt) {
        if (!string.match('[a-zA-Z0-9]+')) {
            array.push(string);
        } else {
            array.push('<span class="' + className + '">' + string + '</span>');
        }
    }
    
    function addSupToPrevious(html, array) {
        var sup = html.search(rxSupStart),
        end = 0,
        last;
        
        if (sup !== -1) {
            end = html.search(rxSupEnd);
            if (end !== -1) {
                last = array.pop();
                end = end + 6;
                array.push(last.slice(0, -7) + html.slice(0, end) + last.slice(-7));
            }
        }
        
        return html.slice(end);
    }
    
    function paragraphIsSentence(html, array) {
        var index = indexSentenceEnd(html);
        
        if (index === -1 || index === html.length) {
            pushSpan(array, "sentence", html, "paragraphIsSentence");
            html = "";
        }
        
        return html;
    }
    
    function paragraphNoMarkup(html, array) {
        var open = html.search(rxOpen),
        index = 0;
        
        if (open === -1) {
            index = indexSentenceEnd(html);
            if (index === -1) {
                index = html.length;
            }
            
            pushSpan(array, "sentence", html.slice(0, index += 1), "paragraphNoMarkup");
        }
        
        return html.slice(index);
    }
    
    function sentenceUncontained(html, array) {
        var open = html.search(rxOpen),
        index = 0,
        close;
        
        if (open !== -1) {
            index = indexSentenceEnd(html);
            if (index === -1) {
                index = html.length;
            }
            
            close = html.search(rxClose);
            if (index < open || index > close) {
                pushSpan(array, "sentence", html.slice(0, index += 1), "sentenceUncontained");
            } else {
                index = 0;
            }
        }
        
        return html.slice(index);
    }
    
    function sentenceContained(html, array) {
        var open = html.search(rxOpen),
        index = 0,
        close,
        count;
        
        if (open !== -1) {
            index = indexSentenceEnd(html);
            if (index === -1) {
                index = html.length;
            }
            
            close = html.search(rxClose);
            if (index > open && index < close) {
                count = html.match(rxClose)[0].length;
                pushSpan(array, "sentence", html.slice(0, close + count), "sentenceContained");
                index = close + count;
            } else {
                index = 0;
            }
        }
        
        return html.slice(index);
    }
    
    function anythingElse(html, array) {
        pushSpan(array, "sentence", html, "anythingElse");
        
        return "";
    }
    
    function guessSenetences() {
        var paragraphs = document.getElementsByTagName("p");

        Array.prototype.forEach.call(paragraphs, function (paragraph) {
            var html = paragraph.innerHTML,
                length = html.length,
                array = [],
                safety = 100;

            while (length && safety) {
                html = addSupToPrevious(html, array);
                if (html.length === length) {
                    if (html.length === length) {
                        html = paragraphIsSentence(html, array);
                        if (html.length === length) {
                            html = paragraphNoMarkup(html, array);
                            if (html.length === length) {
                                html = sentenceUncontained(html, array);
                                if (html.length === length) {
                                    html = sentenceContained(html, array);
                                    if (html.length === length) {
                                        html = anythingElse(html, array);
                                    }
                                }
                            }
                        }
                    }
                }

                length = html.length;
                safety -= 1;
            }

            paragraph.innerHTML = array.join("");
        });
    }
    
    guessSenetences();
}