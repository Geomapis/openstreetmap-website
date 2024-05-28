//= require jquery3
//= require jquery_ujs
//= require jquery.throttle-debounce
//= require js-cookie/dist/js.cookie
//= require popper
//= require bootstrap-sprockets
//= require osm
//= require leaflet/dist/leaflet-src
//= require leaflet.osm
//= require leaflet.map
//= require leaflet.zoom
//= require leaflet.locationfilter
//= require i18n
//= require oauth
//= require matomo
//= require richtext

{
  const application_data = $("head").data();

  I18n.default_locale = OSM.DEFAULT_LOCALE;
  I18n.locale = application_data.locale;
  I18n.fallbacks = true;

  OSM.preferred_editor = application_data.preferredEditor;
  OSM.preferred_languages = application_data.preferredLanguages;

  if (application_data.user) {
    OSM.user = application_data.user;

    if (application_data.userHome) {
      OSM.home = application_data.userHome;
    }
  }

  if (application_data.location) {
    OSM.location = application_data.location;
  }
}

/*
 * Called as the user scrolls/zooms around to manipulate hrefs of the
 * view tab and various other links
 */
window.updateLinks = function (loc, zoom, layers, object) {
  $(".geolink").each(function (index, link) {
    let href = link.href.split(/[?#]/)[0];
    const queryArgs = new URLSearchParams(link.search),
          editlink = $(link).hasClass("editlink");

    for (const arg of ["node", "way", "relation", "changeset", "note"]) {
      queryArgs.delete(arg);
    }

    if (object && editlink) {
      queryArgs.set(object.type, object.id);
    }

    const query = queryArgs.toString();
    if (query) href += "?" + query;

    const hashArgs = {
      lat: loc.lat,
      lon: "lon" in loc ? loc.lon : loc.lng,
      zoom: zoom
    };

    if (layers && !editlink) {
      hashArgs.layers = layers;
    }

    href += OSM.formatHash(hashArgs);

    link.href = href;
  });

  // Disable the button group and also the buttons to avoid
  // inconsistent behaviour when zooming
  var editDisabled = zoom < 13;
  $("#edit_tab")
    .tooltip({ placement: "bottom" })
    .tooltip(editDisabled ? "enable" : "disable")
    .toggleClass("disabled", editDisabled)
    .find("a")
    .toggleClass("disabled", editDisabled);
};

$(document).ready(function () {
  // NB: Turns Turbo Drive off by default. Turbo Drive must be opt-in on a per-link and per-form basis
  // See https://turbo.hotwired.dev/reference/drive#turbo.session.drive
  Turbo.session.drive = false;

  const $expandedSecondaryMenu = $("header nav.secondary > ul"),
        $collapsedSecondaryMenu = $("#compact-secondary-nav > ul"),
        secondaryMenuItems = [],
        breakpointWidth = 768;
  let moreItemWidth = 0;

  function updateHeader() {
    var windowWidth = $(window).width();

    if (windowWidth < breakpointWidth) {
      $("body").addClass("small-nav");
      expandAllSecondaryMenuItems();
    } else {
      $("body").removeClass("small-nav");
      const availableWidth = $expandedSecondaryMenu.width();
      secondaryMenuItems.forEach(function (item) {
        $(item[0]).remove();
      });
      let runningWidth = 0,
          i = 0,
          requiredWidth;
      for (; i < secondaryMenuItems.length; i++) {
        runningWidth += secondaryMenuItems[i][1];
        if (i < secondaryMenuItems.length - 1) {
          requiredWidth = runningWidth + moreItemWidth;
        } else {
          requiredWidth = runningWidth;
        }
        if (requiredWidth > availableWidth) {
          break;
        }
        expandSecondaryMenuItem($(secondaryMenuItems[i][0]));
      }
      for (; i < secondaryMenuItems.length; i++) {
        collapseSecondaryMenuItem($(secondaryMenuItems[i][0]));
      }
    }
  }

  function expandAllSecondaryMenuItems() {
    secondaryMenuItems.forEach(function (item) {
      expandSecondaryMenuItem($(item[0]));
    });
  }

  function expandSecondaryMenuItem($item) {
    $item.children("a")
      .removeClass("dropdown-item")
      .addClass("nav-link")
      .addClass(function () {
        return $(this).hasClass("active") ? "text-secondary-emphasis" : "text-secondary";
      });
    $item.addClass("nav-item").insertBefore("#compact-secondary-nav");
    toggleCompactSecondaryNav();
  }

  function collapseSecondaryMenuItem($item) {
    $item.children("a")
      .addClass("dropdown-item")
      .removeClass("nav-link text-secondary text-secondary-emphasis");
    $item.removeClass("nav-item").appendTo($collapsedSecondaryMenu);
    toggleCompactSecondaryNav();
  }

  function toggleCompactSecondaryNav() {
    $("#compact-secondary-nav").toggle(
      $collapsedSecondaryMenu.find("li").length > 0
    );
  }

  /*
   * Chrome 60 and later seem to fire the "ready" callback
   * before the DOM is fully ready causing us to measure the
   * wrong sizes for the header elements - use a 0ms timeout
   * to defer the measurement slightly as a workaround.
   */
  setTimeout(function () {
    $expandedSecondaryMenu.find("li:not(#compact-secondary-nav)").each(function () {
      secondaryMenuItems.push([this, $(this).width()]);
    });
    moreItemWidth = $("#compact-secondary-nav").width();

    $("header").removeClass("text-nowrap");
    $("header nav.secondary > ul").removeClass("flex-nowrap");

    updateHeader();

    $(window).resize(updateHeader);
    $(document).on("turbo:render", updateHeader);
  }, 0);

  $("#menu-icon").on("click", function (e) {
    e.preventDefault();
    $("header").toggleClass("closed");
  });

  $("nav.primary li a").on("click", function () {
    $("header").toggleClass("closed");
  });

  $("#edit_tab")
    .attr("title", I18n.t("javascripts.site.edit_disabled_tooltip"));
});
