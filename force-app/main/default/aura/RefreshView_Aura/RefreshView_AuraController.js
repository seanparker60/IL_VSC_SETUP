({
    doInit : function( component, event, helper ) {

        console.log( '--- doInit ---' );
        var flow = component.find("flowData");
        var inputVariables = [{
            name: 'recordId',
            type: 'String',
            value: component.get('v.recordId')
        }];
        flow.startFlow("Error_Message_Flow_Screen", inputVariables);

    },

    handleStatusChange : function (component, event) {

        var eventStatus = event.getParam('status');
        console.log('--- handleStatusChange --- ' + eventStatus);
        if(eventStatus === "FINISHED"){
            //$A.get('e.force:refreshView').fire();
        }
    },

    handleRecordUpdated : function( component, event, helper ) {

        console.log( '--- handleRecorUpdated ---' );
        var eventChangeType = event.getParam('changeType');
        console.log('--- event --- ' + eventChangeType);
        //Do Something
        if(eventChangeType === "CHANGED"){
            var navigate = component.get('v.naviagteFlow');
            navigate("FINISH");
        }
    }
})