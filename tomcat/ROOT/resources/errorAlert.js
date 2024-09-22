/*
    Mango - Open Source M2M - http://mango.serotoninsoftware.com
    Copyright (C) 2013-2014 Vemetris.
    @author Alejandro González

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

//==============================================================================
// Non Bloquing Alert
//==============================================================================

//------------------------------------------------------------------------------
var setupNonBloquingAlertDefaults = function () {
    $.blockUI.defaults.fadeIn = 0;
    $.blockUI.defaults.fadeOut = 0;
    $.blockUI.defaults.baseZ = 1200;
};

//------------------------------------------------------------------------------
var nonBlockingAlert = function (html) {
    $.blockUI({
        message: html,
        css: {
            cursor: 'default'
        },
        overlayCSS: {
            cursor: 'default'
        }
    });
    $('.blockOverlay').click($.unblockUI);
    $('.blockMsg').click($.unblockUI);
};

//==============================================================================
// Error Handler
//==============================================================================

//------------------------------------------------------------------------------
var errorAlert = function (message) {
    var imageSrc = 'data:image/png;base64,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';
    var html = '<div style="margin: 10px;"><table style="width: 100%;"><tr><td style="width: 32px; padding: 0;"><img src="' + imageSrc + '" style="margin-left: 12px; margin-right: 12px;" /></td><td style="padding: 0 42px 0 0;">Error: ' + message + '</td></tr></table></div>';
    nonBlockingAlert(html);
};

//------------------------------------------------------------------------------
var errorHandler = function (message, ex) {
    if (typeof mango !== "undefined" && mango.unloading) return;

    dwr.engine._debug("Error: " + ex.name + ", " + ex.message, true);
    if (message == null || message == "") {
        errorAlert("A server error has occured.");
    }
    // Ignore NS_ERROR_NOT_AVAILABLE if Mozilla is being narky
    else if (message.indexOf("0x80040111") != -1) {
        dwr.engine._debug(message);
    }
    else {
        errorAlert(message);
    }
};

//------------------------------------------------------------------------------
var setupDwrErrorAlert = function () {
    setupNonBloquingAlertDefaults();
    dwr.engine.setErrorHandler(errorHandler);
};

setupDwrErrorAlert();
