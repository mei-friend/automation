from lxml import etree

ns = {
    "mei": "http://www.music-encoding.org/ns/mei",
    "xml": "http://www.w3.org/XML/1998/namespace",
}

XML_ID = "{http://www.w3.org/XML/1998/namespace}id"


def add_sbs_every_n(
    active_dom: dict, context_doms: list, sbInterval: int, **addargs
):
    """
    Adds `<sb>` (system beginning) elements every n measures

    :param active_dom: dict containing {filename:Path/str?, dom:etree.Element}
    :type active_dom: dict
    :param context_doms: list containing dom dicts
    :type context_doms: list
    :param n: interval of system beginnings
    :type n: int
    :param addargs: Additional arguments that are unused
    """

    root = active_dom["dom"]

    measures = root.xpath(".//mei:measure", namespaces=ns)

    for count, measure in enumerate(measures):
        if (count + 1) % sbInterval == 0:
            sb = etree.Element("sb")
            parent = measure.getparent()
            parent.insert(parent.index(measure) + 1, sb)

    active_dom["dom"] = root
    output_message = ""
    summary_message = ""

    return active_dom, output_message, summary_message


def remove_all_sbs(active_dom: dict, context_doms: list, **addargs):
    """
    Removes all `<sb>`

    :param active_dom: dict containing {filename:Path/str?, dom:etree.Element}
    :type active_dom: dict
    :param context_doms: list containing dom dicts
    :type context_doms: list
    :param addargs: Additional arguments that are unused
    """

    root = active_dom["dom"]

    sbs = root.xpath(".//mei:sb", namespaces=ns)

    for sb in sbs:
        parent = sb.getparent()
        parent.remove(sb)

    active_dom["dom"] = root
    output_message = ""
    summary_message = ""

    return active_dom, output_message, summary_message


def _template_function(active_dom: dict, context_doms: list, **addargs):
    """
    template function

    :param active_dom: dict containing {filename:Path/str?, dom:etree.Element}
    :type active_dom: dict
    :param context_doms: list containing dom dicts
    :type context_doms: list
    :param addargs: Additional arguments that are unused
    """

    root = active_dom["dom"]

    # xpath_result = root.xpath(".//mei:elem[@attrib='value']", namespaces=ns)

    active_dom["dom"] = root
    output_message = ""
    summary_message = ""

    return active_dom, output_message, summary_message
