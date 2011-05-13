(function($){$.fn.editInPlace=function(options){var settings=$.extend({},$.fn.editInPlace.defaults,options);assertMandatorySettingsArePresent(settings);preloadImage(settings.saving_image);return this.each(function(){var dom=$(this);if(dom.data('editInPlace'))
return;dom.data('editInPlace',true);new InlineEditor(settings,dom).init();});};$.fn.editInPlace.defaults={url:"",bg_over:"#ffc",bg_out:"transparent",hover_class:"",show_buttons:false,save_button:'<button class="inplace_save">Save</button>',cancel_button:'<button class="inplace_cancel">Cancel</button>',params:"",field_type:"text",default_text:"(Click here to add text)",use_html:false,textarea_rows:10,textarea_cols:25,select_text:"Choose new value",select_options:"",text_size:null,saving_text:undefined,saving_image:"",saving_animation_color:'transparent',value_required:false,element_id:"element_id",update_value:"update_value",original_value:'original_value',original_html:"original_html",save_if_nothing_changed:false,on_blur:"save",cancel:"",callback:null,callback_skip_dom_reset:false,success:null,error:null,error_sink:function(idOfEditor,errorString){alert(errorString);},preinit:null,postclose:null,delegate:null};var delegateExample={shouldOpenEditInPlace:function(aDOMNode,aSettingsDict,triggeringEvent){},willOpenEditInPlace:function(aDOMNode,aSettingsDict){},didOpenEditInPlace:function(aDOMNode,aSettingsDict){},shouldCloseEditInPlace:function(aDOMNode,aSettingsDict,triggeringEvent){},willCloseEditInPlace:function(aDOMNode,aSettingsDict){},didCloseEditInPlace:function(aDOMNode,aSettingsDict){},missingCommaErrorPreventer:''};function InlineEditor(settings,dom){this.settings=settings;this.dom=dom;this.originalValue=null;this.didInsertDefaultText=false;this.shouldDelayReinit=false;};$.extend(InlineEditor.prototype,{init:function(){this.setDefaultTextIfNeccessary();this.connectOpeningEvents();},reinit:function(){if(this.shouldDelayReinit)
return;this.triggerCallback(this.settings.postclose,this.dom);this.triggerDelegateCall('didCloseEditInPlace');this.markEditorAsInactive();this.connectOpeningEvents();},setDefaultTextIfNeccessary:function(){if(''!==this.dom.html())
return;this.dom.html(this.settings.default_text);this.didInsertDefaultText=true;},connectOpeningEvents:function(){var that=this;this.dom.bind('mouseenter.editInPlace',function(){that.addHoverEffect();}).bind('mouseleave.editInPlace',function(){that.removeHoverEffect();}).bind('click.editInPlace',function(anEvent){that.openEditor(anEvent);});},disconnectOpeningEvents:function(){this.dom.unbind('.editInPlace');},addHoverEffect:function(){if(this.settings.hover_class)
this.dom.addClass(this.settings.hover_class);else
this.dom.css("background-color",this.settings.bg_over);},removeHoverEffect:function(){if(this.settings.hover_class)
this.dom.removeClass(this.settings.hover_class);else
this.dom.css("background-color",this.settings.bg_out);},openEditor:function(anEvent){if(!this.shouldOpenEditor(anEvent))
return;this.disconnectOpeningEvents();this.removeHoverEffect();this.removeInsertedDefaultTextIfNeccessary();this.saveOriginalValue();this.markEditorAsActive();this.replaceContentWithEditor();this.setInitialValue();this.workAroundMissingBlurBug();this.connectClosingEventsToEditor();this.triggerDelegateCall('didOpenEditInPlace');},shouldOpenEditor:function(anEvent){if(this.isClickedObjectCancelled(anEvent.target))
return false;if(false===this.triggerCallback(this.settings.preinit,this.dom))
return false;if(false===this.triggerDelegateCall('shouldOpenEditInPlace',true,anEvent))
return false;return true;},removeInsertedDefaultTextIfNeccessary:function(){if(!this.didInsertDefaultText||this.dom.html()!==this.settings.default_text)
return;this.dom.html('');this.didInsertDefaultText=false;},isClickedObjectCancelled:function(eventTarget){if(!this.settings.cancel)
return false;var eventTargetAndParents=$(eventTarget).parents().andSelf();var elementsMatchingCancelSelector=eventTargetAndParents.filter(this.settings.cancel);return 0!==elementsMatchingCancelSelector.length;},saveOriginalValue:function(){if(this.settings.use_html)
this.originalValue=this.dom.html();else
this.originalValue=trim(this.dom.text());},restoreOriginalValue:function(){this.setClosedEditorContent(this.originalValue);},setClosedEditorContent:function(aValue){if(this.settings.use_html)
this.dom.html(aValue);else
this.dom.text(aValue);},workAroundMissingBlurBug:function(){var ourInput=this.dom.find(':input');this.dom.parents(':last').find('.editInPlace-active :input').not(ourInput).blur();},replaceContentWithEditor:function(){var buttons_html=(this.settings.show_buttons)?this.settings.save_button+' '+this.settings.cancel_button:'';var editorElement=this.createEditorElement();this.dom.html('<form class="inplace_form" style="display: inline; margin: 0; padding: 0;"></form>').find('form').append(editorElement).append(buttons_html);},createEditorElement:function(){if(-1===$.inArray(this.settings.field_type,['text','textarea','select']))
throw"Unknown field_type <fnord>, supported are 'text', 'textarea' and 'select'";var editor=null;if("select"===this.settings.field_type)
editor=this.createSelectEditor();else if("text"===this.settings.field_type)
editor=$('<input type="text" '+this.inputNameAndClass()
+' size="'+this.settings.text_size+'" />');else if("textarea"===this.settings.field_type)
editor=$('<textarea '+this.inputNameAndClass()
+' rows="'+this.settings.textarea_rows+'" '
+' cols="'+this.settings.textarea_cols+'" />');return editor;},setInitialValue:function(){var initialValue=this.triggerDelegateCall('willOpenEditInPlace',this.originalValue);var editor=this.dom.find(':input');editor.val(initialValue);if(editor.val()!==initialValue)
editor.val('');},inputNameAndClass:function(){return' name="inplace_value" class="inplace_field" ';},createSelectEditor:function(){var editor=$('<select'+this.inputNameAndClass()+'>'
+'<option disabled="true" value="">'+this.settings.select_text+'</option>'
+'</select>');var optionsArray=this.settings.select_options;if(!$.isArray(optionsArray))
optionsArray=optionsArray.split(',');for(var i=0;i<optionsArray.length;i++){var currentTextAndValue=optionsArray[i];if(!$.isArray(currentTextAndValue))
currentTextAndValue=currentTextAndValue.split(':');var value=trim(currentTextAndValue[1]||currentTextAndValue[0]);var text=trim(currentTextAndValue[0]);var option=$('<option>').val(value).text(text);editor.append(option);}
return editor;},connectClosingEventsToEditor:function(){var that=this;function cancelEditorAction(anEvent){that.handleCancelEditor(anEvent);return false;}
function saveEditorAction(anEvent){that.handleSaveEditor(anEvent);return false;}
var form=this.dom.find("form");form.find(".inplace_field").focus().select();form.find(".inplace_cancel").click(cancelEditorAction);form.find(".inplace_save").click(saveEditorAction);if(!this.settings.show_buttons){if("save"===this.settings.on_blur)
form.find(".inplace_field").blur(saveEditorAction);else
form.find(".inplace_field").blur(cancelEditorAction);if($.browser.mozilla||$.browser.msie)
this.bindSubmitOnEnterInInput();}
form.keyup(function(anEvent){var escape=27;if(escape===anEvent.which)
return cancelEditorAction();});if($.browser.safari)
this.bindSubmitOnEnterInInput();form.submit(saveEditorAction);},bindSubmitOnEnterInInput:function(){if('textarea'===this.settings.field_type)
return;var that=this;this.dom.find(':input').keyup(function(event){var enter=13;if(enter===event.which)
return that.dom.find('form').submit();});},handleCancelEditor:function(anEvent){if(false===this.triggerDelegateCall('shouldCloseEditInPlace',true,anEvent))
return;var enteredText=this.dom.find(':input').val();enteredText=this.triggerDelegateCall('willCloseEditInPlace',enteredText);this.restoreOriginalValue();if(hasContent(enteredText)&&!this.isDisabledDefaultSelectChoice())
this.setClosedEditorContent(enteredText);this.reinit();},handleSaveEditor:function(anEvent){if(false===this.triggerDelegateCall('shouldCloseEditInPlace',true,anEvent))
return;var enteredText=this.dom.find(':input').val();enteredText=this.triggerDelegateCall('willCloseEditInPlace',enteredText);if(this.isDisabledDefaultSelectChoice()||this.isUnchangedInput(enteredText)){this.handleCancelEditor(anEvent);return;}
if(this.didForgetRequiredText(enteredText)){this.handleCancelEditor(anEvent);this.reportError("Error: You must enter a value to save this field");return;}
this.showSaving(enteredText);if(this.settings.callback)
this.handleSubmitToCallback(enteredText);else
this.handleSubmitToServer(enteredText);},didForgetRequiredText:function(enteredText){return this.settings.value_required&&(""===enteredText||undefined===enteredText||null===enteredText);},isDisabledDefaultSelectChoice:function(){return this.dom.find('option').eq(0).is(':selected:disabled');},isUnchangedInput:function(enteredText){return!this.settings.save_if_nothing_changed&&this.originalValue===enteredText;},showSaving:function(enteredText){if(this.settings.callback&&this.settings.callback_skip_dom_reset)
return;var savingMessage=enteredText;if(hasContent(this.settings.saving_text))
savingMessage=this.settings.saving_text;if(hasContent(this.settings.saving_image))
savingMessage=$('<img />').attr('src',this.settings.saving_image).attr('alt',savingMessage);this.dom.html(savingMessage);},handleSubmitToCallback:function(enteredText){this.enableOrDisableAnimationCallbacks(true,false);var newHTML=this.triggerCallback(this.settings.callback,this.id(),enteredText,this.originalValue,this.settings.params,this.savingAnimationCallbacks());if(this.settings.callback_skip_dom_reset);else if(undefined===newHTML){this.reportError("Error: Failed to save value: "+enteredText);this.restoreOriginalValue();}
else
this.dom.html(newHTML);if(this.didCallNoCallbacks()){this.enableOrDisableAnimationCallbacks(false,false);this.reinit();}},handleSubmitToServer:function(enteredText){var data=this.settings.update_value+'='+encodeURIComponent(enteredText)
+'&'+this.settings.element_id+'='+this.dom.attr("id")
+((this.settings.params)?'&'+this.settings.params:'')
+'&'+this.settings.original_html+'='+encodeURIComponent(this.originalValue)
+'&'+this.settings.original_value+'='+encodeURIComponent(this.originalValue);this.enableOrDisableAnimationCallbacks(true,false);this.didStartSaving();var that=this;$.ajax({url:that.settings.url,type:"POST",data:data,dataType:"html",complete:function(request){that.didEndSaving();},success:function(html){var new_text=html||that.settings.default_text;that.dom.html(new_text);that.triggerCallback(that.settings.success,html);},error:function(request){that.dom.html(that.originalHTML);if(that.settings.error)
that.triggerCallback(that.settings.error,request);else
that.reportError("Failed to save value: "+request.responseText||'Unspecified Error');}});},triggerCallback:function(aCallback){if(!aCallback)
return;var callbackArguments=Array.prototype.slice.call(arguments,1);return aCallback.apply(this.dom[0],callbackArguments);},triggerDelegateCall:function(aDelegateMethodName,defaultReturnValue,optionalEvent){if(!this.settings.delegate||!$.isFunction(this.settings.delegate[aDelegateMethodName]))
return defaultReturnValue;var delegateReturnValue=this.settings.delegate[aDelegateMethodName](this.dom,this.settings,optionalEvent);return(undefined===delegateReturnValue)?defaultReturnValue:delegateReturnValue;},reportError:function(anErrorString){this.triggerCallback(this.settings.error_sink,this.id(),anErrorString);},id:function(){return this.dom.attr('id');},markEditorAsActive:function(){this.dom.addClass('editInPlace-active');},markEditorAsInactive:function(){this.dom.removeClass('editInPlace-active');},savingAnimationCallbacks:function(){var that=this;return{didStartSaving:function(){that.didStartSaving();},didEndSaving:function(){that.didEndSaving();}};},enableOrDisableAnimationCallbacks:function(shouldEnableStart,shouldEnableEnd){this.didStartSaving.enabled=shouldEnableStart;this.didEndSaving.enabled=shouldEnableEnd;},didCallNoCallbacks:function(){return this.didStartSaving.enabled&&!this.didEndSaving.enabled;},assertCanCall:function(methodName){if(!this[methodName].enabled)
throw new Error('Cannot call '+methodName+' now. See documentation for details.');},didStartSaving:function(){this.assertCanCall('didStartSaving');this.shouldDelayReinit=true;this.enableOrDisableAnimationCallbacks(false,true);this.startSavingAnimation();},didEndSaving:function(){this.assertCanCall('didEndSaving');this.shouldDelayReinit=false;this.enableOrDisableAnimationCallbacks(false,false);this.reinit();this.stopSavingAnimation();},startSavingAnimation:function(){var that=this;this.dom.animate({backgroundColor:this.settings.saving_animation_color},400).animate({backgroundColor:'transparent'},400,'swing',function(){setTimeout(function(){that.startSavingAnimation();},10);});},stopSavingAnimation:function(){this.dom.stop(true).css({backgroundColor:''});},missingCommaErrorPreventer:''});function assertMandatorySettingsArePresent(options){if(options.url||options.callback)
return;throw new Error("Need to set either url: or callback: option for the inline editor to work.");}
function preloadImage(anImageURL){if(''===anImageURL)
return;var loading_image=new Image();loading_image.src=anImageURL;}
function trim(aString){return aString.replace(/^\s+/,'').replace(/\s+$/,'');}
function hasContent(something){if(undefined===something||null===something)
return false;if(0===something.length)
return false;return true;}})(jQuery);