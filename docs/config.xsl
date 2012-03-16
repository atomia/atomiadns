<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                exclude-result-prefixes="fo xsl"  version="1.0">
				
<xsl:output indent="no" mit-xml-declaration="yes"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
    doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" />
			
	<xsl:param name="use.id.as.filename" select="1"/>
	<xsl:param name="admon.graphics" select="1"/>
	<xsl:param name="admon.graphics.path"></xsl:param>
	<xsl:param name="chunk.section.depth" select="1"></xsl:param>
	<xsl:param name="chunk.first.sections" select="1"/>
	<xsl:param name="html.stylesheet" select="'resources/css/style.css'"/>
	
	<xsl:param name="chunker.output.omit-xml-declaration">yes</xsl:param>
	<xsl:param name="appendix.autolabel" select="A"/>
	<xsl:param name="chapter.autolabel" select="1"/>
	<xsl:param name="part.autolabel" select="I"/>
	<xsl:param name="reference.autolabel" select="I"/>
	<xsl:param name="section.autolabel" select="1"/>

	<xsl:param name="suppress.navigation" select="1"/>
	
	<xsl:template name="generate.html.title"/>
	<xsl:param name="generate.index" select="0"></xsl:param>
	<xsl:param name="generate.meta.abstract" select="1"></xsl:param>
	
	
	<xsl:template name="user.head.content">
		<xsl:param name="node" select="."/>
		<script type="text/javascript" src="resources/js/jquery-1.7.1.min.js"></script>
		<script type="text/javascript" src="resources/js/custom.js"></script>
	</xsl:template>


	<xsl:template name="user.header.content">
		<div class="header">
			<a title="Home" href="http://atomia.github.com/atomiadns/" id="books_home"><img alt="Atomia Docs" src="resources/img/a-docs.png" class="logo" /></a>
			<div class="top_nav">
				<ul class="books">
					<li>
						<a title="Home" href="index.html" id="books_home">Home</a>
						<xsl:call-template name="manual_toc"/>
					</li>
					
					<xsl:call-template name="breadcrumbs"/>
				</ul>
				<ul class="pager">
					<xsl:for-each select="preceding::section[name(parent::*) != 'section'][1]">
						<li>
							<a id="pager_prev">
								<xsl:attribute name="href">
									<xsl:call-template name="href.target">
										<xsl:with-param name="object" select="."/>
										<xsl:with-param name="context" select="node"/>
									</xsl:call-template>
								</xsl:attribute>
								<xsl:text>Prev - </xsl:text>
								<xsl:apply-templates select="." mode="title.markup"/>
							</a>
						</li>
					</xsl:for-each>
					<xsl:for-each select="following::section[name(parent::*) != 'section'][1]">
						<li>
							<a id="pager_next">
								<xsl:attribute name="href">
									<xsl:call-template name="href.target">
										<xsl:with-param name="object" select="."/>
										<xsl:with-param name="context" select="node"/>
									</xsl:call-template>
								</xsl:attribute>
								<xsl:text>Next - </xsl:text>
								<xsl:apply-templates select="." mode="title.markup"/>
							</a>
						</li>
					</xsl:for-each>
				</ul>
			</div>
		</div>
	</xsl:template>
    <xsl:template name="user.footer.content">
		<div class="footer">
			<p>Copyright 2012 Atomia AB. All rights reserved.</p>
			<p class="links"><a href="http://www.atomia.com/">Atomia AB</a> | <a href="http://www.atomiadns.com/">AtomiaDNS</a> | <a href="http://www.atomia.com/blog">Blog</a> | <a href="http://www.twitter.com/atomia">Twitter</a></p>
		</div>
		<script type="text/javascript">

		  var _gaq = _gaq || [];
		  _gaq.push(['_setAccount', 'UA-11168442-3']);
		  _gaq.push(['_trackPageview']);

		  (function() {
			var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
			ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
			var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
		  })();

		</script>
	</xsl:template>
	
    <xsl:template name="manual_toc">
		<xsl:param name="this.node" select="."/>
			<ul class="sub_home">
				<xsl:for-each select="/article/section">
					<li>
						<a>
							<xsl:attribute name="href">
								<xsl:call-template name="href.target">
									<xsl:with-param name="object" select="."/>
									<xsl:with-param name="context" select="."/>
								</xsl:call-template>
							</xsl:attribute>
							<xsl:apply-templates select="." mode="title.markup"/>
						</a>
					</li>
				</xsl:for-each>
			</ul>
    </xsl:template>
    <xsl:template name="breadcrumbs">
        <xsl:param name="this.node" select="section[1]"/>
		<li class="current"><a href="javascript:void(0);"><xsl:apply-templates select="$this.node" mode="title.markup"/></a>
			<ul>
				<xsl:for-each select="section">
					<li>
						<a>
							<xsl:attribute name="href">
								<xsl:call-template name="href.target">
									<xsl:with-param name="object" select="."/>
									<xsl:with-param name="context" select="$this.node"/>
								</xsl:call-template>
							</xsl:attribute>
							<xsl:apply-templates select="." mode="title.markup"/>
						</a>
					</li>
				</xsl:for-each>
			</ul>
		</li>
	</xsl:template>
	<xsl:template match="note">
		<p class="note">
			<xsl:apply-templates />
		</p>
	</xsl:template>
</xsl:stylesheet>