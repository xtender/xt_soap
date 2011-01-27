CREATE OR REPLACE PACKAGE xt_soap IS
  -- -----------------------------------------------------------------------------------------------------------
  -- Name         : XT_SOAP (http://xt-r.com)
  -- Based on     : http://www.oracle-base.com/dba/miscellaneous/soap_api
  -- Author       : DR Timothy S Hall
  -- Modified by  : Malakshinov Sayan aka xtender (http://xt-r.com xt.and.r@gmail.com)
  -- Description  : SOAP related functions for consuming web services.
  -- Ammedments   :
  --   When         Who                What
  --   ===========  ========           =========================================================================
  --   04-OCT-2003  Tim Hall           Initial Creation
  --   23-FEB-2006  Tim Hall           Parameterized the "soap" envelope tags.
  --   27-JAN-2011  Malakshinov Sayan  Added function "execute". Commented in javadoc style(for doxygen/javadoc)
  -- -----------------------------------------------------------------------------------------------------------

 /** Request type */
  TYPE t_request IS RECORD (
    method        VARCHAR2(256),
    namespace     VARCHAR2(256),
    body          VARCHAR2(32767),
    envelope_tag  VARCHAR2(30)
  );
 /** Response type */
  TYPE t_response IS RECORD
  (
    doc           XMLTYPE,
    envelope_tag  VARCHAR2(30)
  );
 /** Method's parameter type */
  TYPE t_param IS RECORD(
                          p_name  varchar2(4000),
                          p_type  varchar2(4000),
                          p_value varchar2(4000)
                        );
 /** Collection for methods params */
  TYPE t_params IS TABLE OF t_param;

 /** 
  * Generates new request
  * @param p_method method name, which need to call on SOAP-WS (example,'helloworld')
  * @param p_namespace namespace where to call that method (e.g. 'http://ws_soap_service/WS_SOAP_SERVICE.wsdl')
  * @param p_envelope_tag tag for envelope (DEFAULT 'SOAP-ENV', e.g. jdeveloper creates from pl/sql package - 'env')
  * @return t_request
  */
  FUNCTION new_request(p_method        IN  VARCHAR2,
                       p_namespace     IN  VARCHAR2,
                       p_envelope_tag  IN  VARCHAR2 DEFAULT 'SOAP-ENV')
    RETURN t_request;
 /**
  * Adds param to request
  * @param p_request request on which param append
  * @param p_name param name
  * @param p_type param type
  * @param p_value param value
  */
  PROCEDURE add_parameter(p_request  IN OUT NOCOPY  t_request,
                          p_name     IN             VARCHAR2,
                          p_type     IN             VARCHAR2,
                          p_value    IN             VARCHAR2);
 /**
  * Invokes method
  * @param p_request request
  * @param p_url url for request
  * @param p_action action
  */
  FUNCTION invoke(p_request  IN OUT NOCOPY  t_request,
                  p_url      IN             VARCHAR2,
                  p_action   IN             VARCHAR2)
    RETURN t_response;

 /**
  * Returns tag value of response
  * @param p_response in/out response to parse
  * @param p_name result tag name
  * @param p_namespace namespace
  */
  FUNCTION get_return_value(p_response   IN OUT NOCOPY  t_response,
                            p_name       IN             VARCHAR2,
                            p_namespace  IN             VARCHAR2)
    RETURN VARCHAR2;
      
 /**
  * Creates request, adds params, invokes method and returns 'result' tag value
  * @param p_method method to call
  * @param p_namespace method namespace
  * @param p_envelope_tag envelope tag
  * @param p_proxy ws url
  * @param p_params params collection
  * @return varchar2
  */
  FUNCTION execute(
                   p_method            in varchar2
                  ,p_namespace         in varchar2
                  ,p_envelope_tag      in varchar2 default 'SOAP-ENV'
                  ,p_proxy             in varchar2 default null
                  ,p_params            in t_params default t_params()
                  )
  RETURN VARCHAR2;
     
END xt_soap;
/
CREATE OR REPLACE PACKAGE BODY xt_soap IS
  -- -----------------------------------------------------------------------------------------------------------
  -- Name         : XT_SOAP (http://xt-r.com)
  -- Based on     : http://www.oracle-base.com/dba/miscellaneous/soap_api
  -- Author       : DR Timothy S Hall
  -- Modified by  : Malakshinov Sayan aka xtender (xt.and.r@gmail.com)
  -- Description  : SOAP related functions for consuming web services.
  -- Ammedments   :
  --   When         Who                What
  --   ===========  ========           =========================================================================
  --   04-OCT-2003  Tim Hall           Initial Creation
  --   23-FEB-2006  Tim Hall           Parameterized the "soap" envelope tags.
  --   27-JAN-2011  Malakshinov Sayan  Added function "execute". Commented in javadoc style(for doxygen/javadoc)
  -- -----------------------------------------------------------------------------------------------------------
  -- -----------------------------------------------------------------------------------------------------------

 /** 
  * Generates new request
  * @param p_method method name, which need to call on SOAP-WS (example,'helloworld')
  * @param p_namespace namespace where to call that method (e.g. 'http://ws_soap_service/WS_SOAP_SERVICE.wsdl')
  * @param p_envelope_tag tag for envelope (DEFAULT 'SOAP-ENV', e.g. jdeveloper creates from pl/sql package - 'env')
  * @return t_request
  */
  FUNCTION new_request(p_method        IN  VARCHAR2,
                       p_namespace     IN  VARCHAR2,
                       p_envelope_tag  IN  VARCHAR2 DEFAULT 'SOAP-ENV')
    RETURN t_request AS
  -- -----------------------------------------------------------------------------------------------------------
    l_request  t_request;
  BEGIN
    l_request.method       := p_method;
    l_request.namespace    := p_namespace;
    l_request.envelope_tag := p_envelope_tag;
    RETURN l_request;
  END;
  -- -----------------------------------------------------------------------------------------------------------
  -- -----------------------------------------------------------------------------------------------------------
 /**
  * Adds param to request
  * @param p_request request on which param append
  * @param p_name param name
  * @param p_type param type
  * @param p_value param value
  */
  PROCEDURE add_parameter(p_request    IN OUT NOCOPY  t_request,
                          p_name   IN             VARCHAR2,
                          p_type   IN             VARCHAR2,
                          p_value  IN             VARCHAR2) AS
  -- -----------------------------------------------------------------------------------------------------------
  BEGIN
    p_request.body := p_request.body||'<'||p_name||' xsi:type="'||p_type||'">'||p_value||'</'||p_name||'>';
  END;
  -- -----------------------------------------------------------------------------------------------------------
  -- -----------------------------------------------------------------------------------------------------------
  PROCEDURE generate_envelope(p_request  IN OUT NOCOPY  t_request,
                              p_env      IN OUT NOCOPY  VARCHAR2) AS
  -- -----------------------------------------------------------------------------------------------------------
  BEGIN
    p_env := '<'||p_request.envelope_tag||':Envelope xmlns:'||p_request.envelope_tag||'="http://schemas.xmlsoap.org/soap/envelope/" ' ||
                 'xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xmlns:xsd="http://www.w3.org/1999/XMLSchema">' ||
               '<'||p_request.envelope_tag||':Body>' ||
                 '<'||p_request.method||' '||p_request.namespace||' '||p_request.envelope_tag||':encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">' ||
                     p_request.body ||
                 '</'||p_request.method||'>' ||
               '</'||p_request.envelope_tag||':Body>' ||
             '</'||p_request.envelope_tag||':Envelope>';
  END;
  -- ---------------------------------------------------------------------
  -- ---------------------------------------------------------------------
  PROCEDURE show_envelope(p_env  IN  VARCHAR2) AS
  -- ---------------------------------------------------------------------
    i      PLS_INTEGER;
    l_len  PLS_INTEGER;
  BEGIN
    i := 1; l_len := LENGTH(p_env);
    WHILE (i <= l_len) LOOP
      DBMS_OUTPUT.put_line(SUBSTR(p_env, i, 60));
      i := i + 60;
    END LOOP;
  END;
  -- ---------------------------------------------------------------------
  -- ---------------------------------------------------------------------
  PROCEDURE check_fault(p_response IN OUT NOCOPY  t_response) AS
  -- ---------------------------------------------------------------------
    l_fault_node    XMLTYPE;
    l_fault_code    VARCHAR2(256);
    l_fault_string  VARCHAR2(32767);
  BEGIN
    l_fault_node := p_response.doc.extract('/'||p_response.envelope_tag||':Fault',
                                           'xmlns:'||p_response.envelope_tag||'="http://schemas.xmlsoap.org/soap/envelope/');
    IF (l_fault_node IS NOT NULL) THEN
      l_fault_code   := l_fault_node.extract('/'||p_response.envelope_tag||':Fault/faultcode/child::text()',
                                             'xmlns:'||p_response.envelope_tag||'="http://schemas.xmlsoap.org/soap/envelope/').getstringval();
      l_fault_string := l_fault_node.extract('/'||p_response.envelope_tag||':Fault/faultstring/child::text()',
                                             'xmlns:'||p_response.envelope_tag||'="http://schemas.xmlsoap.org/soap/envelope/').getstringval();
      RAISE_APPLICATION_ERROR(-20000, l_fault_code || ' - ' || l_fault_string);
    END IF;
  END;
  -- ---------------------------------------------------------------------
  -- ---------------------------------------------------------------------
 /**
  * Invokes method
  * @param p_request request
  * @param p_url url for request
  * @param p_action action
  */
  FUNCTION invoke(p_request IN OUT NOCOPY  t_request,
                  p_url     IN             VARCHAR2,
                  p_action  IN             VARCHAR2)
    RETURN t_response AS
  -- ---------------------------------------------------------------------
    l_envelope       VARCHAR2(32767);
    l_http_request   UTL_HTTP.req;
    l_http_response  UTL_HTTP.resp;
    l_response       t_response;
  BEGIN
    generate_envelope(p_request, l_envelope);
    show_envelope(l_envelope);
    l_http_request := UTL_HTTP.begin_request(p_url, 'POST','HTTP/1.1');
    UTL_HTTP.set_header(l_http_request, 'Content-Type', 'text/xml');
    UTL_HTTP.set_header(l_http_request, 'Content-Length', LENGTH(l_envelope));
    UTL_HTTP.set_header(l_http_request, 'SOAPAction', p_action);
    UTL_HTTP.write_text(l_http_request, l_envelope);
    l_http_response := UTL_HTTP.get_response(l_http_request);
    UTL_HTTP.read_text(l_http_response, l_envelope);
    UTL_HTTP.end_response(l_http_response);
    l_response.doc := XMLTYPE.createxml(l_envelope);
    l_response.envelope_tag := p_request.envelope_tag;
    l_response.doc := l_response.doc.extract('/'||l_response.envelope_tag||':Envelope/'||l_response.envelope_tag||':Body/child::node()',
                                             'xmlns:'||l_response.envelope_tag||'="http://schemas.xmlsoap.org/soap/envelope/"');
    -- show_envelope(l_response.doc.getstringval());
    check_fault(l_response);
    RETURN l_response;
  END;
  -- ---------------------------------------------------------------------
  -- ---------------------------------------------------------------------
 /**
  * Returns tag value of response
  * @param p_response in/out response to parse
  * @param p_name result tag name
  * @param p_namespace namespace
  */
  FUNCTION get_return_value(p_response   IN OUT NOCOPY  t_response,
                            p_name       IN             VARCHAR2,
                            p_namespace  IN             VARCHAR2)
    RETURN VARCHAR2 AS
  -- ---------------------------------------------------------------------
  BEGIN
    RETURN p_response.doc.extract('//'||p_name||'/child::text()',p_namespace).getstringval();
  END;
  -- ---------------------------------------------------------------------
  -- ---------------------------------------------------------------------
 /**
  * Creates request, adds params, invokes method and returns 'result' tag value
  * @param p_method method to call
  * @param p_namespace method namespace
  * @param p_envelope_tag envelope tag
  * @param p_proxy ws url
  * @param p_params params collection
  * @return varchar2
  */
  FUNCTION execute(
                   p_method            in varchar2
                  ,p_namespace         in varchar2
                  ,p_envelope_tag      in varchar2 default 'SOAP-ENV'
                  ,p_proxy             in varchar2 default null
                  ,p_params            in t_params default t_params()
                   )
    RETURN VARCHAR2 AS
  -- ---------------------------------------------------------------------
        l_req  t_request;
        l_resp t_response;
   BEGIN
        l_req := new_request( p_method
                             ,'xmlns="' || p_namespace || '"'
                             ,p_envelope_tag
                            );

        for i in 1 .. p_params.count loop
            add_parameter(
                           l_req
                          ,p_params(i).p_name
                          ,p_params(i).p_type
                          ,p_params(i).p_value
                          );
        end loop;
          
        l_resp := invoke(l_req, nvl(p_proxy,p_namespace), p_method);

        RETURN get_return_value(l_resp,
                               'result', -- result tag name
                               'xmlns:m="' || --can be change as "xmlns:n1"
                               p_namespace || '"');

   END execute;
  -- ---------------------------------------------------------------------
END xt_soap;
/
