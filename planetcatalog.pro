;+
;  
;   This code is meant to be used to search and explored Planet Labs' catalog of
;   PlanetScope 4 band datasets. The data is uncalibrated and in it's raw state when
;   downloaded with only an ENVI header file being added that contains the band information
;   associated with the data. 
;
;  :Copyright:
;    (c) 2017 Exelis Visual Information Solutions, Inc., a subsidiary of Harris Corporation.
;    
;    See LICENSE.txt for additional details and information.
;    
;-




;+
; :Description:
;    Procedure to add the extension to ENVI
;-
pro PlanetCatalog_extensions_init
  compile_opt idl2
  e = envi(/current)
  e.addExtension,  'PlanetScope Query Tool', 'planetcatalog', PATH = ''
end

;handle all types of events and just return 0 so that nothing happens
;need to create an object class with all of the methods listed on
;https://www.exelisvis.com/docs/graphicseventhandler.html
function disable_events::MouseDown, win, x, y, buttons, keymods, clicks
  return, 0
end

function disable_events::MouseUp, win, x, y, button
  return, 0
end

function disable_events::MouseMotion, win, x, y, keymods
  return, 0
end

function disable_events::MouseWheel, win, x, y, delta, keymods
  return, 0
end

function disable_events::KeyHandler, win, isASCII, character, $
  keyvalue, x, y, press, release, keywods
  return, 0
end

function disable_events::SelectChange, win, graphic, mode, WasSelected
  return, 0
end

pro disable_events__define
  ; We must subclass from GraphicsEventAdapter.
  void = {disable_events, inherits GraphicsEventAdapter}
end


pro PlanetCatalog_UseExtent, event
  ; click the use extent toggle
  compile_opt idl2

  widget_control, event.top, GET_UVALUE =cData
  cData.use_extent = event.select eq 1 ? !TRUE : !FALSE
end

pro PlanetCatalog_Thumbnail, event
  ; user clicks the download button
  compile_opt idl2

  e = envi(/current)

  widget_control, HOURGLASS = 1
  widget_control, event.top, GET_UVALUE = cData


  ; make sure the API key is filled in
  widget_control, cData.apiText, GET_VALUE = apiKey
  if (apiKey[0] eq '') then begin
    ; no API key - pop up and no-op
    a=dialog_message('Please Enter an API Key to Search', /ERROR)
  endif else begin
    g = widget_info(cData.table, /GEOMETRY)

    ; only process if the whole row was selected
    sel = widget_info(cData.table, /TABLE_SELECT) ; left, top, right, bottom
    if ((sel[0] eq 0) and (sel[2] eq g.xsize-1)) then begin

      widget_control, /CLEAR_EVENTS
      featureSelID = sel[1]

      features = cData.features


      widget_control, cData.status_label, SET_VALUE = 'Getting Thumbnail '+features[featureSelID].ID

      ; get the folder to put the downloads
      widget_control, cData.outfileText, GET_VALUE=outfileText
      if (outfileText[0] eq '') then output_folder = file_basename(e.getTemporaryFilename()) else output_folder=strtrim(outfileText[0],2)

      ; the actual download
      file = GetPlanetThumbnail(features[featureSelID]._LINKS._SELF +'/thumb', APIKEY=strtrim(apiKey[0],2), OUTPUT_FOLDER=output_folder)
      if (file eq '') then return


      img = read_png(file)
      sz=size(img, /DIM)
      cData.thumbnailWin.select
      cData.thumbnailWin.erase
      cData.thumbnailWin.event_handler = obj_new('disable_events')
      i = image(file, /CURRENT)
      i.position = [0.05,0.05, 0.95, 0.95]

      cData.currentImage = i
    endif
  endelse

  widget_control, HOURGLASS = 0
end


pro PlanetCatalog_Download, event
  ; user clicks the download button
  compile_opt idl2
  e = envi(/current)

  widget_control, event.top, GET_UVALUE = cData

  ; make sure the API key is filled in
  widget_control, cData.apiText, GET_VALUE = apiKey
  if (apiKey[0] eq '') then begin
    ; no API key - pop up and no-op
    a = dialog_message('Please Enter an API Key to Search', /ERROR)
  endif else begin
    g = widget_info(cData.table, /GEOMETRY)

    ; only process if the whole row was selected
    sel = widget_info(cData.table, /TABLE_SELECT) ; left, top, right, bottom
    if ((sel[0] eq 0) and (sel[2] eq g.xsize-1)) then begin

      widget_control, /CLEAR_EVENTS
      featureSelID = sel[1]

      features = cData.features

      ans = dialog_message('Download Planet Scene '+features[featureSelID].ID+'?', /QUESTION)
      if (ans eq 'Yes') then begin
        widget_control, cData.status_label, SET_VALUE = 'Downloading '+features[featureSelID].ID

        ; get the broadcast channel variables ready to go. The download callback
        ; will check these and create new instances at the start
        cData.bAbort = !NULL   ;ENVIAbortable()
        cData.bStart = !NULL   ;ENVIStartMessage('Progress Bar Title', cData.bAbort)
        cData.bProgress = !NULL;ENVIProgressMessage('Executing Progress Message', 0, cData.bAbort)

        ; get the folder to put the downloads
        widget_control, cData.outfileText, GET_VALUE=outfileText
        if (outfileText[0] eq '') then output_folder = file_basename(e.getTemporaryFilename()) else output_folder=strtrim(outfileText[0],2)

        ; the actual download
        file = GetPlanetImage(features[featureSelID], APIKEY=strtrim(apiKey[0],2), OUTPUT_FOLDER=output_folder, CBDATA=cData)

        ;check to see if we actually have a file
        ;otherwise we will return
        if (file eq '') or (file eq !NULL) then begin
          widget_control, cData.status_label, SET_VALUE = 'Ready'
          return
        endif

        ; clear the progress message
        Finish = ENVIFinishMessage(cData.bAbort)
        cData.bChannel.Broadcast, Finish

        ; load the results into ENVI
        oView = e.getView()
        oRaster = e.openRaster(file)

        ;Blue 455-515 nm
        ;Green 500-590 nm
        ;Red 590-670 nm
        ;NIR 780-60 nm

        ;check how manyt bands we have
        case oRaster.NBANDS of
          4:begin
            ;check to see if header file exists already
            if ~file_test(file_dirname(file) + path_sep() + file_basename(file, '.tif') + '.hdr') then begin
              oRaster.Metadata.UpdateItem,'band names',['Blue','Green','Red','NIR']
              oRaster.Metadata.AddItem,'wavelength units','nanometers'
              oRaster.Metadata.AddItem,'wavelength', [485,560,660,850]
              oRaster.Metadata.AddItem,'data ignore value', 0
              oRaster.WriteMetadata
            endif
          end
          5:begin
            ;check to see if header file exists already
            if ~file_test(file_dirname(file) + path_sep() + file_basename(file, '.tif') + '.hdr') then begin
              oRaster.Metadata.UpdateItem,'band names',['Red','Green','Blue', 'NIR', 'Mask/Alpha']
              oRaster.Metadata.AddItem,'wavelength units','nanometers'
              oRaster.Metadata.AddItem,'wavelength', [660, 560, 485, 850, 0]
              oRaster.Metadata.AddItem,'data ignore value', 0
              oRaster.WriteMetadata
            endif
          end
          else: begin
            message, 'oRaster has ' + strtrim(oRaster.NBANDS,2) + ' bands, expected 4 or 5!'
          end
        endcase

        oLayer = oView.createLayer(oRaster, /RGB, ERROR = error)
        if error.contains('Layer(s) are incompatible with the established base coordinate system:') then begin
          msg = dialog_message("Cannot display raster with extents/coordinate system in ENVI's display window. " + $
            string(10b) + string(10b) + "Would you like to clear the display and load the raster?", /QUESTION )
          if (msg eq 'Yes') then begin
            oLayer = oView.createLayer(oRaster, /RGB, /CLEAR_DISPLAY)
          endif
        endif
      endif
    endif
  endelse
end

pro PlanetCatalog_Search, event
  compile_opt idl2
  widget_control, HOURGLASS = 1

  widget_control, event.top, GET_UVALUE = cData

  widget_control, cData.apiText, GET_VALUE = apiKey
  if (apiKey[0] eq '') then begin
    a = dialog_message('Please Enter an API Key to Search', /ERROR)
  endif else begin
    ; build the URL query based on the contents of the widgets
    widget_control, cData.stimeText, GET_VALUE = sDate
    widget_control, cData.etimeText, GET_VALUE = eDate
    widget_control, cData.cloudCoverText, GET_VALUE = cloudCover

    extent=0
    if (cData.use_extent) then begin
      print, 'Using Extent'
      e = envi(/current)
      v = e.getView()
      ext = v.getExtent(/GEO)
    endif

    if (cData.hasKey('features')) then oldFeatures = cData.features

    ; call the search - handle no results
    cData.features = GetPlanetCatalog(APIKey=strtrim(apikey[0],2), START_DATE=sDate[0], END_DATE=eDate[0], EXTENT=ext, CLOUD_COVER_MAX=cloudCover)
    if (n_elements(cData.features) gt 0) then begin

      ; load the results into the table widget
      widget_control, cData.table, SET_VALUE = CreateFeatureStruct(cData.features)
    endif else begin
      a=dialog_message('Search returned no results')
      if (oldFeatures ne !NULL) then cData.features = oldFeatures
    endelse
  endelse

  ;clear thumbnail window
  cData.thumbnailWin.select
  cData.thumbnailWin.erase

  ;disable hourglass
  widget_control, HOURGLASS = 0
end


pro PlanetCatalog_Product, event
  compile_opt idl2
  widget_control, event.top, GET_UVALUE=cData
  widget_control, event.id, GET_UVALUE = product
  cData.product_type = product
end


pro PlanetCatalog_Browse, event
  compile_opt idl2
  widget_control, event.top, GET_UVALUE=cData

  widget_control, cData.outfileText, GET_VALUE = curPath
  outfile = dialog_pickfile(/DIRECTORY, PATH=curPath, TITLE = 'Select Download Location')
  if (outfile ne '') then $
    widget_control, cData.outfileText, SET_VALUE = outFile
end


pro PlanetCatalog_Table, event
  compile_opt idl2

  widget_control, event.top, GET_UVALUE = cData

  case tag_names(event, /STRUCTURE_NAME) of
    'WIDGET_TABLE_CELL_SEL':begin
      if (event.SEL_LEFT EQ -1) and (event.SEL_TOP EQ -1) and (event.SEL_RIGHT EQ -1) and (event.SEL_BOTTOM eq -1) then return
      view = widget_info(event.id, /TABLE_VIEW)
      widget_control, event.id, SET_TABLE_SELECT = [-1, event.SEL_TOP, -1, event.SEL_TOP]
      widget_control, event.id, SET_TABLE_VIEW = view
    end
    else:;do nothing
  endcase
end


pro PlanetCatalog_Resize, event
  compile_opt idl2

  widget_control, event.top, GET_UVALUE = cData
  gMiddle = widget_info(cData.middleBase, /GEOMETRY)
  gBottom = widget_info(cData.bottomBase, /GEOMETRY)
  gTopBase = widget_info(cData.topBase, /GEOMETRY)


  newY = event.y-gMiddle.scr_ysize-(2*gMiddle.yPad)-gTopBase.scr_ysize-(2*gTopBase.yPad)-gBottom.scr_ysize-(2*gBottom.yPad)
  widget_control, cData.thumbnailDraw, DRAW_YSIZE=newY, DRAW_XSIZE=newY

  gThumb = widget_info(cData.thumbnailDraw, /GEOMETRY)
  newX = event.x-gThumb.scr_xsize-(2*gThumb.xpad)

  widget_control, cData.table, SCR_XSIZE=newX, SCR_YSIZE=newY

  ;check if we need to resize our image
  if cData.haskey('currentImage') then begin
    if obj_valid(cData.currentImage) then begin
      cData.currentImage.position = [0.05,0.05, 0.95, 0.95]
    endif
  endif
end


function CreateFeatureStruct, features
  ; create a structure from the planet JSON that fits into our table widget
  compile_opt idl2

  fStruct = replicate({PLANET_FEATURE}, features.count())

  foreach f, features, i do begin
    fStruct[i] = {PLANET_FEATURE, f.id, $
      f.properties.acquired, $
      f.properties.cloud_cover, $
      f.properties.sun_azimuth, $
      f.properties.gsd, $
      f.properties.black_fill}

  endforeach
  return, fStruct
end

function GetPlanetCatalog, APIKEY=apikey, $
  START_DATE= start_date, $
  END_DATE=end_date, $
  CLOUD_COVER_MAX=cloud_cover_max, $
  EXTENT=extent

  ; search the planet scenes API
  compile_opt idl2
  ; Planet "Scenes" API endpoint

  quicksearchurl = 'https://api.planet.com/data/v1/quick-search'

  if (APIKey eq !NULL) then APIKey = ''

  jsonString = '{"name": "PSOrthoTile","item_types": ["PSOrthoTile"],"filter": {"type": "AndFilter","config": ['

  ;PERMISSIONS START
  jsonString = jsonString + '{"type":"PermissionFilter","config":["assets:download"]}'

  ;DATES START
  if (end_date ne '') OR (start_date ne '') then begin
    ;if dates exist then create date filter
    dateConfig = ',{"type":"DateRangeFilter","field_name":"acquired","config":{
    if (n_elements(end_date) eq 1) then begin ; expect mm/dd/yyy'
      parts = fix(strsplit(end_date, '/', /EXTRACT))
      if (n_elements(parts) eq 3) then $
        dateConfig = dateConfig +'"lte": "'+ timestamp(year=parts[2], month=parts[0], day=parts[1], hour=23, minute=59, second=59, /UTC)+'"'
    endif
    if (n_elements(end_date) eq 1) AND (n_elements(start_date) eq 1) then begin
      dateConfig = dateConfig + ','
    endif
    if (n_elements(start_date) eq 1) then begin ; expect mm/dd/yyy'
      parts = fix(strsplit(start_date, '/', /EXTRACT))
      if (n_elements(parts) eq 3) then $
        dateConfig = dateConfig +'"gte": "'+ timestamp(year=parts[2], month=parts[0], day=parts[1], hour=23, minute=59, second=59, /UTC)+'"'
    endif
    jsonString= jsonString + dateConfig +'}}'
  endif

  ;CLOUD COVER START
  if (n_elements(cloud_cover_max) eq 1) then begin
    if (cloud_cover_max[0] ne '') then begin
      jsonString+= ',{"type": "RangeFilter","field_name":"cloud_cover","config": { "lt":'+strtrim(cloud_cover_max[0]/100.0,2) +'}}'
    endif
  endif

  ;EXTENT START
  if (n_elements(extent) eq 8) then begin
    jsonString+= ',{"type": "GeometryFilter","field_name": "geometry","config": {"type": "Polygon","coordinates": [['

    ; reorder the extent to Planet's spec
    planetOrder = [2,3,4,5,6,7,0,1]
    extent=extent[planetOrder]

    for i=0, n_elements(extent)-1,2 do begin
      jsonString+= '['+strtrim(string(extent[i], FORMAT = '(f35.15)'),2)+','+strtrim(string(extent[i+1], FORMAT = '(f35.15)'),2)+'],'
    endfor
    ; close the polygon
    jsonString+='['+strtrim(string(extent[0], FORMAT = '(f35.15)'),2)+','+strtrim(string(extent[1], FORMAT = '(f35.15)'),2)+']]]}}'
  endif

  jsonString+= ']}}'

  jsonQuery = JSON_PARSE(jsonString)

  headers = ['Authorization: Basic '+IDL_BASE64([byte(APIKey),byte(':')]),'CONTENT-TYPE: application/json']

  oURL = IDLnetURL( $
    SSL_VERIFY_HOST=0, $
    SSL_VERIFY_PEER=0, $
    HEADER=headers)

  data = oURL->Put(JSON_SERIALIZE(jsonQuery), URL=quickSearchURL,/buffer, /string_array, /POST)
  resp = JSON_PARSE(strjoin(data), /TOSTRUCT)

  return, resp.features
end


function GetPlanetImage_DownloadCB, StatusInfo, ProgressInfo, cbData
  compile_opt idl2

  vCancelFlag = 1

  if (progressInfo[0]) then begin

    if (progressInfo[1] gt 0) and (progressInfo[2] gt 0) then begin

      ; only create a new download dialog if this a real (>2000bytes) download
      if ((cbData.bProgress eq !NULL) AND (progressInfo[1] gt 2000)) then begin
        cbData.bAbort = ENVIAbortable()
        cbData.bStart = ENVIStartMessage('Planet Download', cbData.bAbort)
        cbData.bChannel.Broadcast, cbData.bStart

        cbData.bProgress = ENVIProgressMessage('Downloading', 0, cbData.bAbort)
        cbData.bChannel.Broadcast, cbData.bProgress
      endif

      fpct = (float(ProgressInfo[2])/ProgressInfo[1])*100.
      pct = string(fpct, FORMAT='(f5.1)')

      progLabel = 'Downloading ('+strtrim(ProgressInfo[2]/1000000.0,2)+'/'+strtrim(ProgressInfo[1],2)+') '+pct+'%'

      ; report progress on real downloads (>2000bytes)
      if (cbData.bProgress ne !NULL) then begin
        cbData.bProgress.Percent = fix(fpct)
        cbData.bChannel.Broadcast, cbData.bProgress
        if (cbData.bAbort.Abort_Requested) then begin
          vCancelFlag = 0
        endif
      endif

      widget_control, cbData.status_label, SET_VALUE = progLabel
    endif
  endif

  return, vCancelFlag
end

function DummyBrowser, url
  compile_opt idl2
  tlb = widget_base()
  browser = widget_browser(tlb, VALUE=url)
  widget_control, tlb, /REALIZE
  return, tlb
end

function GetPlanetThumbnail, links, APIKEY=apikey, OUTPUT_FOLDER=output_folder
  fullLinkURL=links ; +'?product='+product_type
  print, 'Getting '+fullLinkURL

  ; download the file
  u = parse_url(fullLinkURL)

  oURL = IDLnetURL( $
    SSL_VERIFY_HOST=0, $
    SSL_VERIFY_PEER=0, $
    URL_HOSTNAME=u.host, $
    URL_PATH=u.path, $
    URL_SCHEME=u.scheme, $
    URL_QUERY=u.query, $
    URL_USERNAME=APIKey)

  ; return the image into a temporary ENVI file
  if (n_elements(output_folder) eq 0) then output_folder = file_dirname(e.getTemporaryFilename())

  sceneSplit = strsplit(links,'/', /EXTRACT)

  outFile = output_folder+path_sep()+strjoin(sceneSplit[-2:-1],'_')+'.tif'

  data = oURL->Get(filename = outFile)

  oURL=!NULL

  return, outFile
end


function GetPlanetImage, feature, OUTPUT_FOLDER=output_folder, APIKEY=apikey, CBDATA=cbdata
  compile_opt idl2

  ; If the url object throws an error it will be caught here
  errorStatus=0
  ;CATCH, errorStatus
  IF (errorStatus NE 0) THEN BEGIN
    CATCH, /CANCEL

    ; Display the error msg in a dialog and in the IDL output log
    ;MESSAGE, !ERROR_STATE.msg
    print, !ERROR_STATE.msg

    ; Get the properties that will tell us more about the error.
    oUrl->GetProperty, RESPONSE_CODE=rspCode, $
      RESPONSE_HEADER=rspHdr, RESPONSE_FILENAME=rspFn
    print, 'rspCode = ', rspCode
    print, 'rspHdr= ', rspHdr
    print, 'rspFn= ', rspFn

    ; Destroy the url object
    oURL=!NULL

    if (tmpFile ne !NULL) then $
      if file_test(tmpFile) then xdisplayfile, tmpFile

    return, !NULL
  endif

  headers = ['Authorization: Basic '+IDL_BASE64([byte(APIKey),byte(':')])]
  e = envi(/current)

  oURL = IDLnetURL( $
    SSL_VERIFY_HOST=0, $
    SSL_VERIFY_PEER=0, $
    HEADER=headers)

  assetURL = feature._LINKS.ASSETS[0]
  data = oURL->Get(URL=assetURL, /buffer, /string_array)
  assetsData = JSON_PARSE(strjoin(data), /TOSTRUCT)
  oURL=!NULL
  maintags = TAG_NAMES(assetsData)

  case 1 of
    (where(maintags eq 'ANALYTIC_DN')) ne -1:begin
      ;      ans = dialog_message('Analytic Asset not available, download Analytic DN instead?', /QUESTION)
      ;      if (ans eq 'Yes') then begin
      tags = TAG_NAMES(assetsData.ANALYTIC_DN)

      if (where(tags eq 'LOCATION') ne -1) then begin
        ;DOWNLOAD
        fullLinkURL = assetsData.ANALYTIC_DN.LOCATION[0]
        HEADERBasicAuth='Authorization: Basic '+IDL_BASE64([byte(APIKey),byte(':')])
        HEADERAPIKey='Authorization: api-key '+APIKey

        ; download the file
        u = parse_url(fullLinkURL)

        oURL = IDLnetURL( $
          SSL_VERIFY_HOST=0, $
          SSL_VERIFY_PEER=0, $
          URL_HOSTNAME=u.host, $
          URL_PATH=u.path, $
          URL_SCHEME=u.scheme, $
          URL_QUERY=u.query, $
          URL_USERNAME=APIKey)

        ; handle the status label callback
        if (n_elements(cbdata) gt 0) then begin
          oURL.SetProperty, CALLBACK_FUNCTION = 'GetPlanetImage_DownloadCB'
          oURL.SetProperty, CALLBACK_DATA = cbdata
        endif

        ; return the image into a temporary ENVI file
        if (n_elements(output_folder) eq 0) then output_folder = file_dirname(e.getTemporaryFilename())

        outFile = output_folder + path_sep() + file_basename(feature.id) + '.tif'
        outHeader = output_folder + path_sep() + file_basename(feature.id) + '.hdr'

        ;check if file exists already
        if file_test(outfile) then begin
          msg = dialog_message('Scene has already been downloaded. Overwrite file and re-download?', /QUESTION)
          if (msg eq 'Yes') then begin
            ;try to delete file if it exists
            file_delete, outFile, /QUIET
            file_delete, outHeader, /QUIET, /ALLOW_NONEXISTENT
            if file_test(outFile) then begin
              raster = e.openraster(outFile, ERROR = error)
              if (error eq '') then begin
                raster.close
                file_delete, outFile, /QUIET
                if file_test(outFile) then begin
                  msg = dialog_message('Cannot overwrite file, locked by another program.')
                  return, !NULL
                endif

                ;actually download our data
                data = oURL->Get(filename = outFile)

                return, outFile
              endif
            endif
          endif else begin
            return, !NULL
          endelse
        endif

        ;download data if the file doesnt exist already
        data = oURL->Get(filename = outFile)

        return, outFile
      endif else begin

        ans = dialog_message('Asset not activated, request activation?', /QUESTION)
        if (ans eq 'Yes') then begin
          ;ACTIVATE
          headers = ['Authorization: Basic '+IDL_BASE64([byte(APIKey),byte(':')])]

          oURL = IDLnetURL( $
            SSL_VERIFY_HOST=0, $
            SSL_VERIFY_PEER=0, $
            HEADER=headers)
          blankData = ''
          data = oURL->Put(blankData,URL=assetsData.ANALYTIC_DN._LINKS.ACTIVATE[0],/BUFFER, /POST)

          a=dialog_message('Asset requested to be activated, try again soon.', /INFORMATION)
          return, !NULL
        endif
      end
    end

    else:begin
      message, 'Unknown case!'
      return, !NULL
    end
  endcase
end


pro PlanetCatalog
  compile_opt idl2
  ; Structure definition for the UI Table
  !NULL={PLANET_FEATURE, ID:'', ACQUIRED:'', CLOUD_COVER:0.0, SUN_AZIMUTH:0.0d, GSD:0.0D, BLACK_FILL:0.0}

  e = envi(/current)
  if (e eq !NULL) then begin
    e = envi()
  endif

  file = FILEPATH('natural_earth_shaded_relief.jp2', ROOT_DIR=e.ROOT_DIR, $
    SUBDIRECTORY = ['data'])
  raster = e.openraster(file)
  e.refresh, /DISABLE
  view = e.getview()
  layer = view.CreateLayer(raster, /CLEAR_DISPLAY)
  view.zoom, /FULL_EXTENT
  e.refresh

  ; UI definition
  tlb = widget_base(TITLE = 'Browse Planet Data', /COLUMN, /TLB_SIZE_EVENTS)
  topBase = widget_base(tlb, /ROW)

  outfileLabel = widget_label(topBase, VALUE='Download Location: ')
  outfileText = widget_text(topBase, XSIZE=50, YSIZE=1, /EDITABLE, VALUE=file_dirname(e.getTemporaryFilename()))
  outfileButton = widget_button(topBase, VALUE = filepath('open.bmp', SUBDIR=['resource','bitmaps']), /BITMAP, /FLAT, EVENT_PRO='PlanetCatalog_Browse')

  middleBase = widget_base(tlb, /ROW, TAB_MODE=1)
  apiLabel = widget_label(middleBase, VALUE = 'API Key: ')
  apiText = widget_text(middleBase, XSIZE=30, YSIZE=1, /EDITABLE)

  stimeLabel=widget_label(middleBase, VALUE='Start Date: ')
  stimeText=widget_text(middleBase, XSIZE=10, YSIZE=1, /EDITABLE)
  etimeLabel=widget_label(middleBase, VALUE='End Date: ')
  etimeText=widget_text(middleBase, XSIZE=10, YSIZE=1, /EDITABLE)

  cloudCoverLabel = widget_label(middleBase, VALUE='Cloud Cover Less Than (%): ')
  cloudCoverText = widget_text(middleBase, XSIZE=5, YSIZE=1, /EDITABLE)

  extentBase = widget_base(middleBase, /ROW, /NONEXCLUSIVE)
  extentButton = widget_button(extentBase, VALUE = 'Search ENVI Extent', EVENT_PRO='PlanetCatalog_UseExtent')

  tableBase = widget_base(tlb, /ROW)
  table = widget_table(tableBase, $
    YSIZE = 50, $
    XSIZE= n_tags({PLANET_FEATURE}), $
    /ROW_MAJOR, $
    /RESIZEABLE_COLUMNS, $
    COLUMN_WIDTHS=[200,125,125,125,125,125], $
    /ALL_EVENTS, $
    EVENT_PRO = 'PlanetCatalog_Table', $
    COLUMN_LABELS = tag_names({PLANET_FEATURE}), $
    /SCROLL)
  gTb = widget_info(table, /GEOMETRY)
  thumbnailDraw = widget_window(tableBase, XSIZE=gTb.scr_ysize, YSIZE=gTb.scr_ysize, /ALIGN_CENTER)

  bottomBase = widget_base(tlb, /ROW)
  searchButton = widget_button(bottombase, VALUE = 'Search', EVENT_PRO='PlanetCatalog_Search')
  thumbnailButton = widget_button(bottomBase, VALUE = 'Show Thumbnail', EVENT_PRO='PlanetCatalog_Thumbnail')
  downloadButton = widget_button(bottomBase, VALUE = 'Download Selected', EVENT_PRO='PlanetCatalog_Download')

  statusLabel = widget_label(bottomBase, VALUE = 'Ready', /DYNAMIC_RESIZE)

  widget_control, tlb, /REALIZE

  widget_control, statusLabel, SET_VALUE = 'Ready'

  widget_control, thumbnailDraw, GET_VALUE = thumbnailWin
  thumbnailWin.select

  ; client data
  cData = DICTIONARY()
  cData.bChannel = e.GetBroadcastChannel()
  cData.outfileText = outfileText
  cData.table = table
  cData.topBase = topBase
  cData.middleBase = middleBase
  cData.bottomBase = bottomBase
  cData.apiText = apiText
  cData.stimeText = stimeText
  cData.etimeText = etimeText
  cData.cloudCoverText = cloudCoverText
  ;cData.features = features
  cData.status_label = statusLabel
  cData.product_type = 'PlanetScope'
  cData.use_extent = !FALSE
  cData.thumbnailDraw = thumbnailDraw
  cData.thumbnailWin = thumbnailWin

  ; store the client data in the widget ID of the top level base
  widget_control, tlb, SET_UVALUE = cData

  ; start the event handler - send top level frame resize events to the _Resize handler
  Xmanager, 'PlanetCatalog', tlb, /NO_BLOCK, EVENT_HANDLER='PlanetCatalog_Resize'
end