-- The actions of controls: a control's record (click, check, select, slide, drag, commit, reset,
-- repaint) runs on the game's own events of that control. Every control a mod makes goes through
-- it: UIKit's and the marker panel's alike.
return function(R, C, U, I)
    function I.action(widget, record)
        local id, state = I.id(widget), I.owner(widget)
        record.widget = widget
        widget.bIsFocusable = true
        I.actions[id], state.actions[id] = record, true
        return record
    end
    -- The record of a widget's actions. A widget the game destroyed (a list it rebuilt) takes its
    -- record with it: another widget at the same address never runs it.
    function I.record(widget)
        local id=I.id(widget)
        local record=I.actions[id]
        if record and not R.valid(record.widget) then I.actions[id]=nil;return nil end
        return record
    end
    local function hook(asset, event, action, resolve, folder)
        R.post(I.path(asset, event, folder), function(widget, ...)
            if resolve then widget = resolve(widget) end
            local record = I.record(widget)
            if record and not record.painting and record[action] then record[action](...) end
        end)
    end
    -- A click hands over this event's widget: wrappers kept from earlier expire.
    R.post(I.path('WB_BaseControl', 'ButtonClicked'), function(widget)
        local record = I.record(widget)
        if record and record.click then record.click(widget) end
    end)
    local slider = 'WB_SliderWithEditableLabel'
    hook('WB_CheckBoxWithLabel', 'SetIsChecked', 'check')
    hook('WB_CheckBoxWithLabel', 'BndEvt__CheckBox_K2Node_ComponentBoundEvent_0_OnCheckBoxComponentStateChanged__DelegateSignature', 'check')
    hook('WB_CheckBoxWithEditableLabel','SetIsChecked','check')
    hook('WB_CheckBoxWithEditableLabel','BndEvt__CheckBox_K2Node_ComponentBoundEvent_0_OnCheckBoxComponentStateChanged__DelegateSignature','check')
    hook('WB_ComboBoxOverlay', 'SetOption', 'select', function(overlay) return overlay.BaseWidget end)
    hook(slider, 'BndEvt__ValueSlider_K2Node_ComponentBoundEvent_0_OnFloatValueChangedEvent__DelegateSignature', 'slide')
    hook(slider, 'ChangeRealValue', 'drag')
    hook(slider, 'CheckDefaultToUpdateUI', 'repaint')
    hook(slider, 'BndEvt__WB_SliderWithEditableLabel_InputField_K2Node_ComponentBoundEvent_3_OnEditableTextBoxCommittedEvent__DelegateSignature', 'commit')
    hook(slider, 'BndEvt__WB_SliderWithEditableLabel_ResetButton_K2Node_ComponentBoundEvent_1_OnButtonClickedEvent__DelegateSignature', 'reset')
    -- (a colour tile of Creative's light colours: the marker panel's swatches)
    hook('WB_LightColorButton', 'Clicked', 'click', nil, '/Game/Blueprints/Gamemodes/CreativeMode/PlacementAndEditUI/TileAndListviews/')
end
