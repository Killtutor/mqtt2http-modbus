/*
    Mango - Open Source M2M - http://mango.serotoninsoftware.com
    Copyright (C) 2006-2011 Serotonin Software Technologies Inc.
    @author Matthew Lohbihler

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/.
*/
var max = function () {
    var max = -java.lang.Double.MAX_VALUE;
    for (var i = 0; i < arguments.length; i++) {
        if (max < arguments[i])
            max = arguments[i];
    }
    return max;
};

var min = function () {
    var min = java.lang.Double.MAX_VALUE;
    for (var i = 0; i < arguments.length; i++) {
        if (min > arguments[i])
            min = arguments[i];
    }
    return min;
};

var avg = function () {
    if (arguments.length == 0)
        return 0;

    var sum = 0;
    for (var i = 0; i < arguments.length; i++)
        sum += arguments[i];

    return sum / arguments.length;
};

var sum = function () {
    var sum = 0;
    for (var i = 0; i < arguments.length; i++)
        sum += arguments[i];
    return sum;
};

var meanAndStdDev = function (values) {
    if (values == null || values.length == 0)
        return null;

    var mean = 0;
    for (var i = 0; i < values.length; i++)
        mean += values[i];
    mean /= values.length;

    var dev = 0;
    var diff;
    for (var i = 0; i < values.length; i++) {
        diff = mean - values[i];
        dev += diff * diff;
    }
    dev /= values.length;
    dev = Math.sqrt(dev);

    return { mean: mean, stdDev: dev };
};
